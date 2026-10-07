import Foundation

public enum GrowthDirection: Sendable, Equatable {
    case increasing
    /// Change within ±0.5 cm: within typical home-measurement differences.
    case littleChange
    /// Height went down by more than 0.5 cm: almost always a measuring difference, not real shrinkage.
    case decreasing
}

public struct VelocityResult: Sendable, Equatable {
    public var cmPerYear: Double
    public var changeCm: Double
    public var intervalDays: Int
    public var from: SeriesPoint
    public var to: SeriesPoint
    public var direction: GrowthDirection
    /// True if either endpoint includes an estimated height.
    public var involvesEstimate: Bool
}

public enum VelocityAvailability: Sendable, Equatable {
    case available(VelocityResult)
    /// Fewer than two measurement days.
    case needsMoreMeasurements
    /// Measurements exist but none are far enough apart; a measurement on or after `date` will be.
    case needsMoreTime(earliestUsefulDate: Date)
}

/// Height velocity (growth speed). Conservative by design (docs/growth-engine.md §5):
/// - same-day measurements are already averaged in `GrowthSeries`;
/// - the interval must be at least 182 days (≈ 6 months), because home-measurement error and seasonal
///   variation make shorter intervals misleading when annualised;
/// - among eligible earlier points, the one closest to 12 months before the latest is used.
public enum GrowthVelocityCalculator {
    public static let minimumIntervalDays = 182
    public static let preferredIntervalDays = 365
    public static let littleChangeThresholdCm = 0.5

    public static func velocity(for series: GrowthSeries, calendar: Calendar) -> VelocityAvailability {
        guard let latest = series.latest, series.points.count >= 2 else { return .needsMoreMeasurements }
        let candidates = series.points.dropLast().compactMap { point -> (SeriesPoint, Int)? in
            let days = AgeMath.days(from: point.date, to: latest.date, calendar: calendar)
            return days >= minimumIntervalDays ? (point, days) : nil
        }
        guard let chosen = candidates.min(by: { abs($0.1 - preferredIntervalDays) < abs($1.1 - preferredIntervalDays) }) else {
            let first = series.points[0]
            let earliest = calendar.date(byAdding: .day, value: minimumIntervalDays, to: first.date) ?? first.date
            return .needsMoreTime(earliestUsefulDate: earliest)
        }
        let (from, days) = chosen
        let change = latest.heightCm - from.heightCm
        let years = Double(days) / 365.25
        let direction: GrowthDirection
        if change > littleChangeThresholdCm { direction = .increasing }
        else if change < -littleChangeThresholdCm { direction = .decreasing }
        else { direction = .littleChange }
        return .available(VelocityResult(
            cmPerYear: change / years,
            changeCm: change,
            intervalDays: days,
            from: from,
            to: latest,
            direction: direction,
            involvesEstimate: from.quality == .estimate || latest.quality == .estimate
        ))
    }
}
