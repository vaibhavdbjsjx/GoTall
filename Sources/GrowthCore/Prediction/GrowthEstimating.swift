import Foundation

/// Boundary for the future prediction engine (Phase 5: CDC reference layer + scenario/conditional model).
///
/// Nothing here computes a height. `PendingGrowthEstimator` exists so the UI can be built against
/// the real interface without ever displaying an invented number.
public enum EstimateAvailability: Equatable, Sendable {
    /// Eligible age (4–17), engine not shipped yet.
    case engineNotAvailable
    /// Ages 2–3: chart only (docs/scientific-prediction-review.md §6.2 rule 6).
    case chartOnlyAge
    /// 18–20: near adult height, trend messaging only.
    case nearAdult
    /// 21+: measured height is adult height.
    case adult
}

public protocol GrowthEstimating: Sendable {
    func availability(for profile: GrowthProfile, on date: Date, calendar: Calendar) -> EstimateAvailability
}

public struct PendingGrowthEstimator: GrowthEstimating {
    public init() {}

    public func availability(for profile: GrowthProfile, on date: Date, calendar: Calendar) -> EstimateAvailability {
        guard let age = profile.age(on: date, calendar: calendar) else { return .engineNotAvailable }
        switch age.band {
        case .adult: return .adult
        case .youngAdult: return .nearAdult
        case .infant: return .chartOnlyAge
        case .child where age.years < 4: return .chartOnlyAge
        case .child, .teen: return .engineNotAvailable
        }
    }
}
