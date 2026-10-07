import Foundation

// MARK: Products

/// App Store product identifiers. Prices are never written in code: they come from the App Store
/// (or the local StoreKit configuration file in development). See docs/phase-5-commercial.md §4.
public enum SubscriptionProductID {
    public static let monthly = "com.example.growthapp.premium.monthly"
    public static let yearly = "com.example.growthapp.premium.yearly"
    public static let all: [String] = [yearly, monthly]
    public static let groupName = "Premium"
}

public enum SubscriptionPeriodUnit: String, Sendable, Equatable {
    case month, year
}

/// A purchasable plan as shown on the paywall. Built from a StoreKit `Product`.
public struct SubscriptionPlan: Sendable, Equatable, Identifiable {
    public var id: String
    public var displayName: String
    /// Localised price exactly as the App Store formats it, e.g. "$39.99".
    public var displayPrice: String
    public var price: Decimal
    public var currencyCode: String
    public var period: SubscriptionPeriodUnit
    public var isFamilyShareable: Bool
    /// Free trial or introductory offer description. `nil` when there is none (the launch plan has none).
    public var introductoryOffer: String?

    public init(id: String, displayName: String, displayPrice: String, price: Decimal, currencyCode: String,
                period: SubscriptionPeriodUnit, isFamilyShareable: Bool, introductoryOffer: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.displayPrice = displayPrice
        self.price = price
        self.currencyCode = currencyCode
        self.period = period
        self.isFamilyShareable = isFamilyShareable
        self.introductoryOffer = introductoryOffer
    }

    public var periodNoun: String { period == .year ? "year" : "month" }
    public var periodAdverb: String { period == .year ? "yearly" : "monthly" }

    /// "$39.99 per year".
    public var priceLine: String { "\(displayPrice) per \(periodNoun)" }

    /// Plain-language billing terms shown next to the purchase button (App Store Guideline 3.1.2).
    public var billingTerms: String {
        "Billed \(displayPrice) every \(periodNoun) until you cancel. Renews automatically unless cancelled at least 24 hours before the end of the current period. Cancel anytime in Settings › Apple Account › Subscriptions."
    }

    /// For a yearly plan, the monthly equivalent ("$3.33 a month"), formatted in the plan's currency.
    public func monthlyEquivalent(locale: Locale = .current) -> String? {
        guard period == .year else { return nil }
        let monthly = (price as NSDecimalNumber).dividing(by: 12, withBehavior: NSDecimalNumberHandler(
            roundingMode: .down, scale: 2, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false))
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = locale
        return formatter.string(from: monthly)
    }

    /// Whole-percent saving of this yearly plan against 12 months of `monthly`, computed from real prices.
    /// `nil` unless the saving is at least 1%. Never compared against an invented "original" price.
    public func savingPercent(comparedTo monthly: SubscriptionPlan?) -> Int? {
        guard period == .year, let monthly, monthly.period == .month, monthly.currencyCode == currencyCode else { return nil }
        let yearOfMonthly = NSDecimalNumber(decimal: monthly.price).multiplying(by: 12).doubleValue
        guard yearOfMonthly > 0 else { return nil }
        let saving = Int(((1 - NSDecimalNumber(decimal: price).doubleValue / yearOfMonthly) * 100).rounded(.down))
        return saving >= 1 ? saving : nil
    }
}

// MARK: Verification abstraction

/// Platform-neutral copy of the fields of a StoreKit `Transaction` that decide access.
public struct TransactionSnapshot: Sendable, Equatable {
    public var productID: String
    public var originalID: String
    public var purchaseDate: Date
    public var expirationDate: Date?
    public var revocationDate: Date?
    public var isFamilyShared: Bool
    public var isUpgraded: Bool

    public init(productID: String, originalID: String, purchaseDate: Date, expirationDate: Date?,
                revocationDate: Date? = nil, isFamilyShared: Bool = false, isUpgraded: Bool = false) {
        self.productID = productID
        self.originalID = originalID
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.revocationDate = revocationDate
        self.isFamilyShared = isFamilyShared
        self.isUpgraded = isUpgraded
    }
}

/// Platform-neutral copy of `Product.SubscriptionInfo.RenewalInfo` + renewal state.
public struct RenewalSnapshot: Sendable, Equatable {
    public enum State: Sendable, Equatable {
        case subscribed, expired, inBillingRetryPeriod, inGracePeriod, revoked
    }
    public var productID: String
    public var state: State
    public var willAutoRenew: Bool
    public var gracePeriodExpirationDate: Date?

    public init(productID: String, state: State, willAutoRenew: Bool, gracePeriodExpirationDate: Date? = nil) {
        self.productID = productID
        self.state = state
        self.willAutoRenew = willAutoRenew
        self.gracePeriodExpirationDate = gracePeriodExpirationDate
    }
}

/// Mirrors StoreKit's `VerificationResult`. Only `.verified` values can grant access.
public enum Verified<Value: Sendable & Equatable>: Sendable, Equatable {
    case verified(Value)
    case unverified(Value, reason: String)

    public var trustedValue: Value? {
        if case .verified(let value) = self { return value }
        return nil
    }
}

/// Turns verified transaction data into an `EntitlementState`. Pure, so every branch is unit-tested.
///
/// Rules:
/// - unverified transactions and renewal info are ignored (they can never unlock anything);
/// - unknown product IDs, upgraded (superseded) and revoked transactions don't grant access;
/// - a transaction is active until its expiration date, or until the grace-period end while Apple retries billing;
/// - when several are active, the one with the latest expiration wins.
public enum EntitlementResolver {
    public static func resolve(transactions: [Verified<TransactionSnapshot>], renewals: [Verified<RenewalSnapshot>],
                               now: Date, knownProducts: [String] = SubscriptionProductID.all) -> EntitlementState {
        let trusted = transactions.compactMap(\.trustedValue).filter { knownProducts.contains($0.productID) }
        let renewalsByProduct = Dictionary(renewals.compactMap(\.trustedValue).map { ($0.productID, $0) }, uniquingKeysWith: { a, _ in a })

        func graceEnd(_ t: TransactionSnapshot) -> Date? {
            guard let r = renewalsByProduct[t.productID], r.state == .inGracePeriod else { return nil }
            return r.gracePeriodExpirationDate ?? t.expirationDate
        }
        func isActive(_ t: TransactionSnapshot) -> Bool {
            guard t.revocationDate == nil, !t.isUpgraded else { return false }
            guard let expiration = t.expirationDate else { return true }
            if expiration > now { return true }
            if let grace = graceEnd(t), grace > now { return true }
            return false
        }

        let active = trusted.filter(isActive).max { ($0.expirationDate ?? .distantFuture) < ($1.expirationDate ?? .distantFuture) }
        if let t = active {
            let renewal = renewalsByProduct[t.productID]
            let status: EntitlementState.Status
            if renewal?.state == .inGracePeriod || (t.expirationDate.map { $0 <= now } ?? false) {
                status = .gracePeriod
            } else if renewal?.willAutoRenew == false {
                status = .cancelled
            } else {
                status = .active
            }
            return EntitlementState(status: status, productID: t.productID, expirationDate: t.expirationDate, isFamilyShared: t.isFamilyShared)
        }

        let latest = trusted.max { $0.purchaseDate < $1.purchaseDate }
        if let latest, latest.revocationDate != nil {
            return EntitlementState(status: .revoked, productID: latest.productID, expirationDate: latest.expirationDate, isFamilyShared: latest.isFamilyShared)
        }
        if let latest, renewalsByProduct[latest.productID]?.state == .inBillingRetryPeriod {
            return EntitlementState(status: .billingRetry, productID: latest.productID, expirationDate: latest.expirationDate, isFamilyShared: latest.isFamilyShared)
        }
        if let latest {
            return EntitlementState(status: .expired, productID: latest.productID, expirationDate: latest.expirationDate, isFamilyShared: latest.isFamilyShared)
        }
        return .free
    }
}

// MARK: Service boundary

public enum PurchaseOutcome: Sendable, Equatable {
    /// A verified transaction now grants access.
    case purchased(EntitlementState)
    /// The person closed the App Store sheet. Not an error.
    case cancelled
    /// Waiting for approval (Ask to Buy) or extra authentication. Access unlocks when it completes.
    case pending
    case failed(String)
}

public enum RestoreOutcome: Sendable, Equatable {
    case restored(EntitlementState)
    case nothingToRestore
    case failed(String)
}

public enum SubscriptionError: Error, Sendable, Equatable {
    case productsUnavailable
    case network
    case other(String)

    public var message: String {
        switch self {
        case .productsUnavailable: return "Plans aren't available right now. Please try again later."
        case .network: return "Prices couldn't load. Check your connection and try again."
        case .other(let message): return message
        }
    }
}

/// Everything the app needs from the store. StoreKit stays behind this protocol
/// (`StoreKitSubscriptionService` in AppFeatures); tests and screenshots use fakes.
@MainActor
public protocol SubscriptionService: AnyObject {
    func loadPlans() async throws -> [SubscriptionPlan]
    func purchase(planID: String) async -> PurchaseOutcome
    func restore() async -> RestoreOutcome
    /// Recomputes access from the device's verified transactions (works offline: StoreKit caches them).
    func currentEntitlement() async -> EntitlementState
    /// Starts listening for transactions that arrive outside a purchase (renewals, refunds, Ask to Buy approvals,
    /// purchases on another device). The handler receives the recomputed state.
    func startObservingUpdates(_ handler: @escaping @MainActor (EntitlementState) -> Void)
}
