import Foundation

/// Patterns where it's reasonable to suggest mentioning growth to a doctor. Never a diagnosis.
/// DRAFT rules pending medical-reviewer approval (docs/growth-engine.md §9).
public enum GrowthSignpost: Sendable, Equatable {
    /// Latest measured (non-estimated) height is below the 3rd percentile.
    case belowThirdPercentile
    /// Latest measured height is above the 97th percentile.
    case aboveNinetySeventhPercentile
    /// Two measured points at least 12 months apart crossed two or more major percentile lines downward.
    case crossedLinesDownward(linesCrossed: Int, months: Int)
}

public enum SignpostEngine {
    public static let crossingLinesThreshold = 2
    public static let crossingMinimumDays = 365

    public static func signposts(for series: GrowthSeries, calendar: Calendar) -> [GrowthSignpost] {
        // Only measured heights: estimates are too uncertain to raise any flag.
        let measured = series.chartablePoints.filter { $0.quality != .estimate }
        guard let latest = measured.last, let latestZ = latest.percentile?.z else { return [] }
        var result: [GrowthSignpost] = []
        if latestZ < MajorPercentile.p3.z { result.append(.belowThirdPercentile) }
        if latestZ > MajorPercentile.p97.z { result.append(.aboveNinetySeventhPercentile) }

        // Compare with the most recent measured point at least 12 months earlier.
        if let earlier = measured.dropLast().last(where: { AgeMath.days(from: $0.date, to: latest.date, calendar: calendar) >= crossingMinimumDays }),
           let earlierZ = earlier.percentile?.z, latestZ < earlierZ {
            let crossed = MajorPercentile.allCases.filter { $0.z < earlierZ && $0.z > latestZ }.count
            if crossed >= crossingLinesThreshold {
                let months = AgeMath.days(from: earlier.date, to: latest.date, calendar: calendar) * 12 / 365
                result.append(.crossedLinesDownward(linesCrossed: crossed, months: months))
            }
        }
        return result
    }
}

/// Reference curves for drawing, computed once per (sex, age window).
public struct ReferenceCurve: Sendable, Equatable, Identifiable {
    public struct Point: Sendable, Equatable {
        public var ageMonths: Double
        public var heightCm: Double
    }
    public var line: MajorPercentile
    public var points: [Point]
    public var id: Int { line.rawValue }
}

public enum ReferenceCurves {
    public static func curves(sex: ReferenceSex, reference: GrowthReference, ageMonths range: ClosedRange<Double>,
                              lines: [MajorPercentile] = MajorPercentile.allCases) -> [ReferenceCurve] {
        let ages = reference.tabulatedAges(for: .stature, sex: sex).filter { range.contains($0) }
        return lines.map { line in
            ReferenceCurve(line: line, points: ages.compactMap { age in
                PercentileCalculator.height(atZ: line.z, ageMonths: age, sex: sex, reference: reference).map { .init(ageMonths: age, heightCm: $0) }
            })
        }
    }
}
