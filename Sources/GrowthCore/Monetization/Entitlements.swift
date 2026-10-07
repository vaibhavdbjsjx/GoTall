import Foundation

/// Premium features planned for the MVP (docs/monetization-strategy.md §1).
/// Safety content, the basic estimate, the chart and measurement history are never listed here.
public enum PremiumFeature: String, CaseIterable, Sendable {
    case multipleProfiles
    case doctorReport
    case advancedAnalytics
}

/// Boundary for StoreKit 2 (Phase 10). No billing code exists yet.
public protocol EntitlementProviding: Sendable {
    func isUnlocked(_ feature: PremiumFeature) -> Bool
}

/// Development builds: everything unlocked, no paywall. Replaced by a StoreKit-backed provider in Phase 10.
public struct DevelopmentEntitlements: EntitlementProviding {
    public init() {}
    public func isUnlocked(_ feature: PremiumFeature) -> Bool { true }
}
