#if os(iOS)
import Foundation
import StoreKit
import GrowthCore

/// StoreKit 2 implementation of `SubscriptionService`.
///
/// - Access is computed only from `VerificationResult.verified` transactions (`EntitlementResolver`); StoreKit
///   checks the JWS signature on the device, so no secret or server is needed.
/// - Transactions are finished only after verification.
/// - `Transaction.updates` and subscription-status updates are observed for renewals, refunds, Ask to Buy
///   approvals and purchases made on other devices.
/// - `Transaction.currentEntitlements` is cached by the system, so relaunching offline recovers Premium.
@MainActor
public final class StoreKitSubscriptionService: SubscriptionService {
    private let productIDs: [String]
    private var products: [String: Product] = [:]
    private var updateTasks: [Task<Void, Never>] = []

    public init(productIDs: [String] = SubscriptionProductID.all) {
        self.productIDs = productIDs
    }

    deinit {
        updateTasks.forEach { $0.cancel() }
    }

    // MARK: Products

    public func loadPlans() async throws -> [SubscriptionPlan] {
        let loaded: [Product]
        do {
            loaded = try await Product.products(for: productIDs)
        } catch {
            throw SubscriptionError.network
        }
        guard !loaded.isEmpty else { throw SubscriptionError.productsUnavailable }
        for product in loaded { products[product.id] = product }
        return loaded.compactMap(Self.plan(from:))
    }

    static func plan(from product: Product) -> SubscriptionPlan? {
        guard let subscription = product.subscription else { return nil }
        let unit: SubscriptionPeriodUnit = subscription.subscriptionPeriod.unit == .year ? .year : .month
        return SubscriptionPlan(id: product.id, displayName: product.displayName, displayPrice: product.displayPrice, price: product.price,
                                currencyCode: product.priceFormatStyle.currencyCode, period: unit, isFamilyShareable: product.isFamilyShareable,
                                introductoryOffer: subscription.introductoryOffer.map(describe))
    }

    static func describe(_ offer: Product.SubscriptionOffer) -> String {
        let period = offer.period
        let unit: String
        switch period.unit {
        case .day: unit = period.value == 1 ? "day" : "days"
        case .week: unit = period.value == 1 ? "week" : "weeks"
        case .month: unit = period.value == 1 ? "month" : "months"
        case .year: unit = period.value == 1 ? "year" : "years"
        @unknown default: unit = "periods"
        }
        switch offer.paymentMode {
        case .freeTrial: return "\(period.value)-\(unit) free trial"
        default: return "Introductory price \(offer.displayPrice) for \(period.value) \(unit)"
        }
    }

    // MARK: Purchase

    public func purchase(planID: String) async -> PurchaseOutcome {
        do {
            if products[planID] == nil { _ = try await loadPlans() }
            guard let product = products[planID] else { return .failed(SubscriptionError.productsUnavailable.message) }
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    return .purchased(await currentEntitlement())
                case .unverified:
                    // Never unlock on an unverified transaction.
                    return .failed("The App Store couldn't verify this purchase, so nothing was unlocked. If you were charged, tap Restore purchases.")
                }
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed("The purchase didn't complete. You haven't been charged. Please try again.")
            }
        } catch let error as SubscriptionError {
            return .failed(error.message)
        } catch let error as StoreKitError {
            return Self.outcome(for: error)
        } catch let error as Product.PurchaseError {
            switch error {
            case .purchaseNotAllowed:
                return .failed("Purchases aren't allowed on this device. Check Screen Time settings or ask the account owner.")
            case .productUnavailable:
                return .failed(SubscriptionError.productsUnavailable.message)
            default:
                return .failed("The purchase didn't complete. You haven't been charged. Please try again.")
            }
        } catch {
            return .failed("The purchase didn't complete. You haven't been charged. Please try again.")
        }
    }

    static func outcome(for error: StoreKitError) -> PurchaseOutcome {
        switch error {
        case .userCancelled: return .cancelled
        case .networkError: return .failed("The App Store couldn't be reached. Check your connection and try again.")
        case .notAvailableInStorefront: return .failed("Premium isn't available in your App Store country yet.")
        default: return .failed("The purchase didn't complete. You haven't been charged. Please try again.")
        }
    }

    // MARK: Restore

    public func restore() async -> RestoreOutcome {
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            return .failed("Restore cancelled.")
        } catch {
            return .failed("The App Store couldn't be reached. Check your connection and try again.")
        }
        let state = await currentEntitlement()
        return state.isPremium ? .restored(state) : .nothingToRestore
    }

    // MARK: Entitlements

    public func currentEntitlement() async -> EntitlementState {
        var transactions: [Verified<TransactionSnapshot>] = []
        for await result in Transaction.currentEntitlements {
            transactions.append(Self.snapshot(result))
        }
        // The latest transaction per product lets expired and refunded states be described accurately.
        for id in productIDs {
            if let latest = await Transaction.latest(for: id) { transactions.append(Self.snapshot(latest)) }
        }
        return EntitlementResolver.resolve(transactions: transactions, renewals: await renewals(), now: Date(), knownProducts: productIDs)
    }

    private func renewals() async -> [Verified<RenewalSnapshot>] {
        if products.isEmpty { _ = try? await loadPlans() }
        guard let subscription = products.values.compactMap(\.subscription).first,
              let statuses = try? await subscription.status else { return [] }
        return statuses.map { status in
            let state: RenewalSnapshot.State
            switch status.state {
            case .subscribed: state = .subscribed
            case .expired: state = .expired
            case .inBillingRetryPeriod: state = .inBillingRetryPeriod
            case .inGracePeriod: state = .inGracePeriod
            case .revoked: state = .revoked
            default: state = .expired
            }
            switch status.renewalInfo {
            case .verified(let info):
                return .verified(RenewalSnapshot(productID: info.currentProductID, state: state, willAutoRenew: info.willAutoRenew,
                                                 gracePeriodExpirationDate: info.gracePeriodExpirationDate))
            case .unverified(let info, let error):
                return .unverified(RenewalSnapshot(productID: info.currentProductID, state: state, willAutoRenew: info.willAutoRenew,
                                                   gracePeriodExpirationDate: info.gracePeriodExpirationDate), reason: String(describing: error))
            }
        }
    }

    static func snapshot(_ result: VerificationResult<Transaction>) -> Verified<TransactionSnapshot> {
        switch result {
        case .verified(let t): return .verified(map(t))
        case .unverified(let t, let error): return .unverified(map(t), reason: String(describing: error))
        }
    }

    static func map(_ t: Transaction) -> TransactionSnapshot {
        TransactionSnapshot(productID: t.productID, originalID: String(t.originalID), purchaseDate: t.purchaseDate,
                            expirationDate: t.expirationDate, revocationDate: t.revocationDate,
                            isFamilyShared: t.ownershipType == .familyShared, isUpgraded: t.isUpgraded)
    }

    // MARK: Updates

    public func startObservingUpdates(_ handler: @escaping @MainActor (EntitlementState) -> Void) {
        updateTasks.forEach { $0.cancel() }
        updateTasks = [
            Task { [weak self] in
                for await result in Transaction.updates {
                    if case .verified(let transaction) = result { await transaction.finish() }
                    guard let self else { return }
                    handler(await self.currentEntitlement())
                }
            },
            Task { [weak self] in
                for await _ in Product.SubscriptionInfo.Status.updates {
                    guard let self else { return }
                    handler(await self.currentEntitlement())
                }
            }
        ]
    }
}
#endif
