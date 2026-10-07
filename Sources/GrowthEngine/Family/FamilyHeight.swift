import Foundation

/// Family-height (mid-parental) range. **Context only**: never presented as the person's predicted height
/// and never combined with the growth-trajectory scenario (docs/scientific-prediction-review.md §2, §6.2).
public struct FamilyHeightRange: Sendable, Equatable {
    /// Tanner mid-parental target.
    public var targetCm: Double
    public var lowCm: Double
    public var highCm: Double
    /// Where the target sits among adult heights in the reference (e.g. "around the 60th percentile").
    public var targetAdultPercentile: PercentileResult?
    /// True if either parent's height was an estimate (self-reported heights tend to be overestimated).
    public var usesEstimatedParentHeight: Bool
}

public enum FamilyHeightCalculator {
    /// Tanner, Goldstein & Whitehouse (1970): sex adjustment of 13 cm.
    public static let sexAdjustmentCm = 13.0
    /// Commonly cited theoretical range (≈ 3rd–97th percentile); later revisions suggest ±9–10 cm.
    public static let halfRangeCm = 8.5
    /// Parent heights outside this range are treated as entry errors and not used.
    public static let plausibleParentRange: ClosedRange<Double> = 120...230

    /// Boys: (father + mother + 13) / 2. Girls: (father + mother − 13) / 2. Range: target ± 8.5 cm.
    /// Returns `nil` unless both parents' heights are known and plausible; missing values are never inferred.
    public static func range(motherCm: Double?, fatherCm: Double?, sex: ReferenceSex, usesEstimate: Bool, reference: GrowthReference) -> FamilyHeightRange? {
        guard let motherCm, let fatherCm,
              plausibleParentRange.contains(motherCm), plausibleParentRange.contains(fatherCm) else { return nil }
        let adjustment = sex == .male ? sexAdjustmentCm : -sexAdjustmentCm
        let target = (fatherCm + motherCm + adjustment) / 2
        var percentile: PercentileResult?
        if let adultAge = reference.adultAgeMonths(for: .stature, sex: sex) {
            percentile = try? PercentileCalculator.percentile(heightCm: target, ageMonths: adultAge, sex: sex, reference: reference).get()
        }
        return FamilyHeightRange(targetCm: target, lowCm: target - halfRangeCm, highCm: target + halfRangeCm,
                                 targetAdultPercentile: percentile, usesEstimatedParentHeight: usesEstimate)
    }
}
