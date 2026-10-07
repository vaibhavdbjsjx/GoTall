import Foundation
import Observation

/// App-wide entitlement state. Views read `access(_:)` and `canAddProfile(existingCount:)`; nothing else
/// in the UI knows about subscriptions.
///
/// Launch behaviour: starts as `.free` (nothing is unlocked before verification), then `start()` recomputes
/// from StoreKit's verified, on-device transactions. That works offline, so relaunching without a network
/// recovers Premium without a server.
@MainActor
@Observable
public final class EntitlementStore {
    public private(set) var state: EntitlementState
    public private(set) var hasLoaded = false
    /// Set briefly after a purchase or restore succeeds, so screens can play the unlock transition once.
    public private(set) var justUnlocked = false

    @ObservationIgnored public let service: SubscriptionService
    @ObservationIgnored private var started = false

    public init(service: SubscriptionService, initialState: EntitlementState = .free) {
        self.service = service
        self.state = initialState
    }

    public var isPremium: Bool { state.isPremium }

    public func access(_ feature: PremiumFeature) -> FeatureAccess {
        EntitlementPolicy.access(feature, state: state)
    }

    public func canAddProfile(existingCount: Int) -> Bool {
        EntitlementPolicy.canAddProfile(existingCount: existingCount, state: state)
    }

    /// Call once at launch. Safe to call again (no duplicate listeners).
    public func start() async {
        if !started {
            started = true
            service.startObservingUpdates { [weak self] newState in
                self?.apply(newState)
            }
        }
        await refresh()
    }

    public func refresh() async {
        apply(await service.currentEntitlement())
        hasLoaded = true
    }

    public func apply(_ newState: EntitlementState) {
        let unlocked = !state.isPremium && newState.isPremium
        state = newState
        if unlocked { justUnlocked = true }
    }

    public func acknowledgeUnlock() { justUnlocked = false }

    /// Restore from outside the paywall (Profile). Applies any verified entitlement found.
    public func restore() async -> RestoreOutcome {
        let outcome = await service.restore()
        if case .restored(let restored) = outcome { apply(restored) }
        return outcome
    }

    /// Words for the subscription card in Profile, derived from verified state only.
    public func statusDescription(plans: [SubscriptionPlan] = [], calendar: Calendar = .current, locale: Locale = .current) -> String {
        let planName = state.productID == SubscriptionProductID.monthly ? "Monthly plan" : (state.productID == SubscriptionProductID.yearly ? "Yearly plan" : "Premium")
        let date = state.expirationDate.map { DisplayFormat.day($0, calendar: calendar, locale: locale) }
        let shared = state.isFamilyShared ? " Shared with you through Family Sharing." : ""
        switch state.status {
        case .active:
            return (date.map { "\(planName) · renews on \($0)." } ?? "\(planName) is active.") + shared
        case .cancelled:
            return (date.map { "\(planName) · ends on \($0). It won't renew." } ?? "\(planName) won't renew.") + shared
        case .gracePeriod:
            return "Apple couldn't take the latest payment. Premium stays on while Apple retries; you can update payment details in Settings."
        case .billingRetry:
            return "Premium is paused because Apple couldn't take the latest payment. Updating payment details in Settings restores it."
        case .expired:
            return "Your Premium subscription has ended. Your profiles, measurements and reports you saved are all still here."
        case .revoked:
            return "Premium access was removed (refund or Family Sharing change). All your data is still here."
        case .none:
            return "Doctor-ready reports, advanced growth analysis and family profiles. Your growth result, chart and history stay free."
        }
    }
}

/// Paywall state machine. Owns loading plans, purchasing and restoring, and reports each outcome in words
/// people understand. A cancelled App Store sheet is reported neutrally, never as an error.
@MainActor
@Observable
public final class PaywallModel {
    public enum PlansState: Equatable {
        case loading
        case loaded([SubscriptionPlan])
        case failed(String)
    }

    public enum PurchaseState: Equatable {
        case idle
        case purchasing(planID: String)
        case restoring
        case succeeded
        case pending
        case cancelled
        case failed(String)
        case nothingToRestore
    }

    public private(set) var plans: PlansState = .loading
    public private(set) var purchase: PurchaseState = .idle
    public var selectedPlanID: String?

    @ObservationIgnored private let store: EntitlementStore

    public init(store: EntitlementStore) {
        self.store = store
    }

    public var loadedPlans: [SubscriptionPlan] {
        if case .loaded(let plans) = plans { return plans }
        return []
    }

    public var selectedPlan: SubscriptionPlan? {
        loadedPlans.first { $0.id == selectedPlanID } ?? loadedPlans.first
    }

    public var monthlyPlan: SubscriptionPlan? { loadedPlans.first { $0.period == .month } }

    public var isBusy: Bool {
        switch purchase {
        case .purchasing, .restoring: return true
        default: return false
        }
    }

    public func loadPlans() async {
        plans = .loading
        do {
            let loaded = try await store.service.loadPlans().sorted { ($0.period == .year ? 0 : 1) < ($1.period == .year ? 0 : 1) }
            guard !loaded.isEmpty else { throw SubscriptionError.productsUnavailable }
            plans = .loaded(loaded)
            if selectedPlanID == nil || !loaded.contains(where: { $0.id == selectedPlanID }) {
                // Yearly is pre-selected because it's the plan most families keep for a growth year. Both prices
                // are shown in full, and there is no trial to be pre-selected into.
                selectedPlanID = loaded.first { $0.period == .year }?.id ?? loaded.first?.id
            }
        } catch let error as SubscriptionError {
            plans = .failed(error.message)
        } catch {
            plans = .failed(SubscriptionError.network.message)
        }
    }

    public func purchaseSelected() async {
        guard let plan = selectedPlan, !isBusy else { return }
        purchase = .purchasing(planID: plan.id)
        switch await store.service.purchase(planID: plan.id) {
        case .purchased(let state):
            store.apply(state)
            purchase = state.isPremium ? .succeeded : .failed("The purchase couldn't be confirmed. Nothing was unlocked. Try Restore purchases.")
        case .cancelled:
            purchase = .cancelled
        case .pending:
            purchase = .pending
        case .failed(let message):
            purchase = .failed(message)
        }
    }

    public func restore() async {
        guard !isBusy else { return }
        purchase = .restoring
        switch await store.service.restore() {
        case .restored(let state):
            store.apply(state)
            purchase = state.isPremium ? .succeeded : .nothingToRestore
        case .nothingToRestore:
            purchase = .nothingToRestore
        case .failed(let message):
            purchase = .failed(message)
        }
    }

    public func clearMessage() {
        if !isBusy { purchase = .idle }
    }

    /// One-line status for the area under the purchase button. `nil` while idle.
    public var statusMessage: String? {
        switch purchase {
        case .idle, .purchasing, .restoring: return nil
        case .succeeded: return "Premium is active."
        case .pending: return "Waiting for approval. Premium unlocks as soon as the purchase is approved."
        case .cancelled: return "Purchase cancelled."
        case .failed(let message): return message
        case .nothingToRestore: return "No previous purchase was found for this Apple Account."
        }
    }
}

/// When a Premium suggestion may appear on Home. Only after the free product has delivered real value
/// (a growth trend exists), never during onboarding or at launch, and not again for 60 days once dismissed.
public enum PremiumOfferPolicy {
    public static let snoozeDays = 60

    public static func shouldSuggest(analysis: GrowthAnalysis, isPremium: Bool, dismissedAt: Date?, now: Date, calendar: Calendar) -> Bool {
        guard !isPremium else { return false }
        if let dismissedAt, let until = calendar.date(byAdding: .day, value: snoozeDays, to: dismissedAt), now < until { return false }
        guard case .available = analysis.velocity else { return false }
        return analysis.series.chartablePoints.count >= 2
    }
}
