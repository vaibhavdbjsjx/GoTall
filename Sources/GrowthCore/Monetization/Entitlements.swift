import Foundation

/// Premium features (docs/monetization-strategy.md §1, docs/phase-5-commercial.md §3).
/// The growth result, percentile, chart, estimate, family range, history, habits, reminders, export and
/// safety content are free and are deliberately not listed here.
public enum PremiumFeature: String, CaseIterable, Sendable {
    /// Adding a second or later profile. Existing profiles are never locked (see `EntitlementPolicy`).
    case multipleProfiles
    case doctorReport
    case advancedAnalytics
}

/// The single answer the UI asks for. Views never inspect subscription details directly.
public enum FeatureAccess: Sendable, Equatable {
    case available
    /// Show a labelled preview built from the person's real data, plus a way to learn about Premium.
    case preview
}

/// What the person currently has, derived only from verified transactions (`EntitlementResolver`).
public struct EntitlementState: Sendable, Equatable {
    public enum Status: Sendable, Equatable {
        /// No subscription found.
        case none
        /// Subscribed and set to renew.
        case active
        /// Subscribed until `expirationDate`, renewal turned off.
        case cancelled
        /// A renewal payment failed but Apple keeps access open while it retries.
        case gracePeriod
        /// A renewal payment failed and access is paused while Apple retries.
        case billingRetry
        case expired
        /// Refunded, or Family Sharing access removed.
        case revoked
    }

    public var status: Status
    public var productID: String?
    public var expirationDate: Date?
    public var isFamilyShared: Bool

    public init(status: Status, productID: String? = nil, expirationDate: Date? = nil, isFamilyShared: Bool = false) {
        self.status = status
        self.productID = productID
        self.expirationDate = expirationDate
        self.isFamilyShared = isFamilyShared
    }

    public static let free = EntitlementState(status: .none)

    public var isPremium: Bool {
        switch status {
        case .active, .cancelled, .gracePeriod: return true
        case .none, .billingRetry, .expired, .revoked: return false
        }
    }
}

/// Central access rules. The only place that decides what Premium unlocks.
public enum EntitlementPolicy {
    /// Free profiles: one. Profiles that already exist always stay fully usable, with or without Premium,
    /// so an expired subscription (or the move from the all-unlocked development builds) never locks data.
    public static let freeProfileLimit = 1

    public static func access(_ feature: PremiumFeature, state: EntitlementState) -> FeatureAccess {
        state.isPremium ? .available : .preview
    }

    public static func canAddProfile(existingCount: Int, state: EntitlementState) -> Bool {
        state.isPremium || existingCount < freeProfileLimit
    }
}

/// Retained for code that predates StoreKit; reads from an `EntitlementState`.
public protocol EntitlementProviding: Sendable {
    func isUnlocked(_ feature: PremiumFeature) -> Bool
}

public struct StaticEntitlements: EntitlementProviding {
    public var state: EntitlementState
    public init(state: EntitlementState) { self.state = state }
    public func isUnlocked(_ feature: PremiumFeature) -> Bool {
        EntitlementPolicy.access(feature, state: state) == .available
    }
}
