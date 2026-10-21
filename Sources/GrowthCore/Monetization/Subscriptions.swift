import Foundation

// MARK: Products

/// App Store product identifiers. Prices are never written in code: they come from the App Store
/// (or the local StoreKit configuration file in development). See docs/phase-5-commercial.md §4.
public enum SubscriptionProductID {
    public static let weekly = "app.stature.height.pro.weekly"
    public static let monthly = "app.stature.height.pro.monthly"
    public static let yearly = "app.stature.height.pro.yearly"
    /// One-time, non-consumable purchase. Not part of the subscription group.
    public static let lifetime = "app.stature.height.pro.lifetime"
    public static let subscriptions: [String] = [yearly, monthly, weekly]
    public static let all: [String] = [yearly, monthly, weekly, lifetime]
    public static let groupName = "Stature Pro"
}

/// How a plan is billed. `lifetime` is a single payment with no renewal.
public enum SubscriptionPeriodUnit: String, Sendable, Equatable {
    case week, month, year, lifetime

    /// Paywall order: the plan most people keep first, the one-time option last.
    public var sortOrder: Int {
        switch self {
        case .year: return 0
        case .month: return 1
        case .week: return 2
        case .lifetime: return 3
        }
    }
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

    public var isLifetime: Bool { period == .lifetime }

    public var periodNoun: String {
        switch period {
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        case .lifetime: return "lifetime"
        }
    }

    public var periodAdverb: String {
        switch period {
        case .week: return "weekly"
        case .month: return "monthly"
        case .year: return "yearly"
        case .lifetime: return "once"
        }
    }

    /// Short plan name for the paywall ("Yearly", "Lifetime").
    public var planTitle: String {
        switch period {
        case .week: return "Weekly"
        case .month: return "Monthly"
        case .year: return "Yearly"
        case .lifetime: return "Lifetime"
        }
    }

    /// "$34.99 per year", or "$49.99 once" for lifetime.
    public var priceLine: String { isLifetime ? "\(displayPrice) once" : "\(displayPrice) per \(periodNoun)" }

    /// "$34.99/year" or "$49.99 one time", for buttons.
    public var shortPrice: String { isLifetime ? "\(displayPrice) one time" : "\(displayPrice)/\(periodNoun)" }

    /// Plain-language billing terms shown next to the purchase button (App Store Guideline 3.1.2).
    public var billingTerms: String {
        if isLifetime {
            return "One payment of \(displayPrice). No subscription and nothing renews. Restore it on any device signed in to the same Apple Account."
        }
        let start = introductoryOffer.map { "\($0), then billed" } ?? "Billed"
        return "\(start) \(displayPrice) every \(periodNoun) until you cancel. Renews automatically unless cancelled at least 24 hours before the end of the current period. Cancel anytime in Settings › Apple Account › Subscriptions."
    }

    /// For a weekly plan, what a year costs at that rate, so weekly pricing is never shown without its total.
    public func yearlyCost(locale: Locale = .current) -> String? {
        guard period == .week else { return nil }
        let year = NSDecimalNumber(decimal: price).multiplying(by: 52)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = locale
        return formatter.string(from: year)
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
/// - Apple's verified subscription status is authoritative: if every verified status for a product says expired or
///   revoked, that product grants nothing even if a cached transaction still shows a later expiration date
///   (found in StoreKit testing: `currentEntitlements` can lag behind an expiry or refund);
/// - when several are active, the one with the latest expiration wins.
public enum EntitlementResolver {
    public static func resolve(transactions: [Verified<TransactionSnapshot>], renewals: [Verified<RenewalSnapshot>],
                               now: Date, knownProducts: [String] = SubscriptionProductID.all) -> EntitlementState {
        let trusted = transactions.compactMap(\.trustedValue).filter { knownProducts.contains($0.productID) }
        let trustedRenewals = renewals.compactMap(\.trustedValue)
        let renewalsByProduct = Dictionary(trustedRenewals.map { ($0.productID, $0) }, uniquingKeysWith: { a, _ in a })
        func statusEnded(_ productID: String) -> RenewalSnapshot.State? {
            let statuses = trustedRenewals.filter { $0.productID == productID }
            guard !statuses.isEmpty, statuses.allSatisfy({ $0.state == .expired || $0.state == .revoked }) else { return nil }
            return statuses.contains { $0.state == .revoked } ? .revoked : .expired
        }

        func graceEnd(_ t: TransactionSnapshot) -> Date? {
            guard let r = renewalsByProduct[t.productID], r.state == .inGracePeriod else { return nil }
            return r.gracePeriodExpirationDate ?? t.expirationDate
        }
        func isActive(_ t: TransactionSnapshot) -> Bool {
            guard t.revocationDate == nil, !t.isUpgraded, statusEnded(t.productID) == nil else { return false }
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
        if let latest, latest.revocationDate != nil || statusEnded(latest.productID) == .revoked {
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
