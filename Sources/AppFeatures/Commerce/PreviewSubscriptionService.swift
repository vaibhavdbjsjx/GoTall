#if os(iOS) && DEBUG
import Foundation
import GrowthCore

/// DEBUG-only stand-in for StoreKit, for simulator screenshots and UI tests (`-storeMode <mode>`).
/// Prices mirror the local StoreKit configuration file, which holds test values only (docs/phase-5-commercial.md §4).
/// The real purchase path is covered by StoreKit tests against `Products.storekit` (App/Tests).
@MainActor
public final class PreviewSubscriptionService: SubscriptionService {
    public enum Mode: String {
        /// Free user; purchases succeed after a short delay.
        case free
        case premium
        case cancelled
        case gracePeriod
        case expired
        case familyShared
        /// Purchases are cancelled in the App Store sheet.
        case cancelPurchase
        /// Purchases fail.
        case failPurchase
        /// Purchases wait for Ask to Buy approval.
        case pending
        /// Purchases never finish (to show the loading state).
        case hang
        /// Plans can't load.
        case unavailable
    }

    let mode: Mode
    var state: EntitlementState
    var handler: (@MainActor (EntitlementState) -> Void)?

    public init(mode: Mode) {
        self.mode = mode
        let year = Calendar.current.date(byAdding: .year, value: 1, to: Date())
        switch mode {
        case .premium: state = EntitlementState(status: .active, productID: SubscriptionProductID.yearly, expirationDate: year)
        case .cancelled: state = EntitlementState(status: .cancelled, productID: SubscriptionProductID.yearly, expirationDate: Calendar.current.date(byAdding: .day, value: 40, to: Date()))
        case .gracePeriod: state = EntitlementState(status: .gracePeriod, productID: SubscriptionProductID.monthly, expirationDate: Date())
        case .expired: state = EntitlementState(status: .expired, productID: SubscriptionProductID.monthly, expirationDate: Calendar.current.date(byAdding: .day, value: -10, to: Date()))
        case .familyShared: state = EntitlementState(status: .active, productID: SubscriptionProductID.yearly, expirationDate: year, isFamilyShared: true)
        default: state = .free
        }
    }

    public static var plans: [SubscriptionPlan] {
        [SubscriptionPlan(id: SubscriptionProductID.yearly, displayName: "Premium Yearly", displayPrice: "$39.99", price: Decimal(string: "39.99")!,
                          currencyCode: "USD", period: .year, isFamilyShareable: true),
         SubscriptionPlan(id: SubscriptionProductID.monthly, displayName: "Premium Monthly", displayPrice: "$5.99", price: Decimal(string: "5.99")!,
                          currencyCode: "USD", period: .month, isFamilyShareable: true)]
    }

    public func loadPlans() async throws -> [SubscriptionPlan] {
        try await Task.sleep(nanoseconds: 300_000_000)
        if mode == .unavailable { throw SubscriptionError.network }
        return Self.plans
    }

    public func purchase(planID: String) async -> PurchaseOutcome {
        try? await Task.sleep(nanoseconds: 900_000_000)
        switch mode {
        case .cancelPurchase: return .cancelled
        case .failPurchase: return .failed("The purchase didn't complete. You haven't been charged. Please try again.")
        case .pending: return .pending
        case .hang:
            try? await Task.sleep(nanoseconds: 3_600_000_000_000)
            return .cancelled
        default:
            state = EntitlementState(status: .active, productID: planID,
                                     expirationDate: Calendar.current.date(byAdding: planID == SubscriptionProductID.yearly ? .year : .month, value: 1, to: Date()))
            return .purchased(state)
        }
    }

    public func restore() async -> RestoreOutcome {
        try? await Task.sleep(nanoseconds: 600_000_000)
        return state.isPremium ? .restored(state) : .nothingToRestore
    }

    public func currentEntitlement() async -> EntitlementState { state }

    public func startObservingUpdates(_ handler: @escaping @MainActor (EntitlementState) -> Void) {
        self.handler = handler
    }
}
#endif
