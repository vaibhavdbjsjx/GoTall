import Foundation

public struct PercentileResult: Equatable, Sendable {
    public var z: Double
    /// 0–100, full precision. Use `PercentileFormatter` for display.
    public var percentile: Double
    public var ageMonths: Double
    public var referenceID: String
}

public enum PercentileError: Error, Equatable, Sendable {
    case ageBelowReference(minimumMonths: Double)
    case ageAboveReference(maximumMonths: Double)
    case invalidHeight
}

public enum PercentileCalculator {
    public static func percentile(heightCm: Double, ageMonths: Double, sex: ReferenceSex, reference: GrowthReference) -> Result<PercentileResult, PercentileError> {
        guard heightCm.isFinite, heightCm > 0 else { return .failure(.invalidHeight) }
        guard let coverage = reference.coverage(for: .stature, sex: sex) else { return .failure(.ageBelowReference(minimumMonths: 0)) }
        if ageMonths < coverage.lowerBound { return .failure(.ageBelowReference(minimumMonths: coverage.lowerBound)) }
        if ageMonths > coverage.upperBound { return .failure(.ageAboveReference(maximumMonths: coverage.upperBound)) }
        guard let lms = reference.lms(for: .stature, sex: sex, ageMonths: ageMonths) else { return .failure(.invalidHeight) }
        let z = lms.zScore(for: heightCm)
        return .success(PercentileResult(z: z, percentile: StandardNormal.cdf(z) * 100, ageMonths: ageMonths, referenceID: reference.id))
    }

    /// Height (cm) at a given z for an age, e.g. to draw percentile curves.
    public static func height(atZ z: Double, ageMonths: Double, sex: ReferenceSex, reference: GrowthReference) -> Double? {
        reference.lms(for: .stature, sex: sex, ageMonths: ageMonths)?.value(atZ: z)
    }
}

/// The CDC's major percentile lines and their exact z-scores (Φ⁻¹(p)).
public enum MajorPercentile: Int, CaseIterable, Sendable, Comparable {
    case p3 = 3, p10 = 10, p25 = 25, p50 = 50, p75 = 75, p90 = 90, p97 = 97

    public var z: Double {
        switch self {
        case .p3: return -1.880793608151251
        case .p10: return -1.2815515655446004
        case .p25: return -0.6744897501960817
        case .p50: return 0
        case .p75: return 0.6744897501960817
        case .p90: return 1.2815515655446004
        case .p97: return 1.880793608151251
        }
    }

    public static func < (lhs: MajorPercentile, rhs: MajorPercentile) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Presents percentiles without false precision: "63rd", never "63.48th".
public enum PercentileFormatter {
    /// "63rd", "below the 1st", "above the 99th".
    public static func ordinal(_ percentile: Double) -> String {
        if percentile < 0.5 { return "below the 1st" }
        if percentile > 99.5 { return "above the 99th" }
        let value = min(max(Int(percentile.rounded()), 1), 99)
        return ordinalNumber(value)
    }

    /// "63rd percentile", "below the 1st percentile".
    public static func phrase(_ percentile: Double) -> String {
        ordinal(percentile) + " percentile"
    }

    public static func ordinalNumber(_ value: Int) -> String {
        let tens = value % 100
        if (11...13).contains(tens) { return "\(value)th" }
        switch value % 10 {
        case 1: return "\(value)st"
        case 2: return "\(value)nd"
        case 3: return "\(value)rd"
        default: return "\(value)th"
        }
    }
}
