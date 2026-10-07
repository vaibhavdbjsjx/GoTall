import Foundation

/// One row of the CDC stature-for-age file.
struct CDCStatureRow: Sendable {
    let ageMonths: Double
    let l: Double
    let m: Double
    let s: Double
    /// CDC's published smoothed P3, P5, P10, P25, P50, P75, P90, P95, P97 (used to validate the LMS maths).
    let publishedPercentiles: [Double]

    var lms: LMS { LMS(l: l, m: m, s: s) }
}

/// CDC 2000 Growth Charts, stature-for-age, 2–20 years (24–240 months), public domain.
/// Data: Reference/cdc2000/statage.csv (provenance and verification in Reference/cdc2000/PROVENANCE.md).
public struct CDC2000Reference: GrowthReference {
    public let id = "CDC2000"
    public let displayName = "CDC growth charts (2000)"
    public let citation = "Kuczmarski RJ et al. 2000 CDC Growth Charts for the United States: methods and development. Vital Health Stat 11(246), 2002."
    public var dataVersion: String { "statage.csv sha256:" + CDC2000StatureData.sourceSHA256.prefix(12) }

    public init() {}

    func rows(for sex: ReferenceSex) -> [CDCStatureRow] {
        sex == .male ? CDC2000StatureData.male : CDC2000StatureData.female
    }

    public func coverage(for measure: GrowthMeasure, sex: ReferenceSex) -> ClosedRange<Double>? {
        let rows = rows(for: sex)
        guard let first = rows.first, let last = rows.last else { return nil }
        return first.ageMonths...last.ageMonths
    }

    public func adultAgeMonths(for measure: GrowthMeasure, sex: ReferenceSex) -> Double? {
        rows(for: sex).last?.ageMonths
    }

    public func tabulatedAges(for measure: GrowthMeasure, sex: ReferenceSex) -> [Double] {
        rows(for: sex).map(\.ageMonths)
    }

    /// Linear interpolation of L, M and S between the two tabulated ages that bracket `ageMonths`.
    /// Rows are 0.5–1 month apart, so linear and cubic interpolation differ negligibly for stature.
    public func lms(for measure: GrowthMeasure, sex: ReferenceSex, ageMonths: Double) -> LMS? {
        let rows = rows(for: sex)
        guard let first = rows.first, let last = rows.last,
              ageMonths.isFinite, ageMonths >= first.ageMonths, ageMonths <= last.ageMonths else { return nil }
        // Binary search for the first row with age >= ageMonths.
        var low = 0
        var high = rows.count - 1
        while low < high {
            let mid = (low + high) / 2
            if rows[mid].ageMonths < ageMonths { low = mid + 1 } else { high = mid }
        }
        let upper = rows[low]
        if upper.ageMonths == ageMonths || low == 0 { return upper.lms }
        let lower = rows[low - 1]
        let t = (ageMonths - lower.ageMonths) / (upper.ageMonths - lower.ageMonths)
        return LMS.interpolate(lower.lms, upper.lms, fraction: t)
    }
}
