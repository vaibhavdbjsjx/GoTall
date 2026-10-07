import Foundation

/// Sex used to select a sex-specific reference chart.
public enum ReferenceSex: String, Sendable, CaseIterable {
    case female
    case male
}

public enum GrowthMeasure: String, Sendable {
    case stature
}

/// A growth reference that the chart and estimate engines select at runtime instead of hard-coding CDC.
/// See docs/growth-reference-architecture.md. Implementations: CDC 2000 (launch). WHO 2007 / IAP 2015 only after licensing.
public protocol GrowthReference: Sendable {
    var id: String { get }
    var displayName: String { get }
    var citation: String { get }
    /// Identifies the exact data used (e.g. a checksum), stored alongside computed results.
    var dataVersion: String { get }
    /// Supported ages in months, or `nil` if the measure isn't covered.
    func coverage(for measure: GrowthMeasure, sex: ReferenceSex) -> ClosedRange<Double>?
    /// Interpolated LMS at an exact age in months, or `nil` outside coverage.
    func lms(for measure: GrowthMeasure, sex: ReferenceSex, ageMonths: Double) -> LMS?
    /// Age (months) treated as "adult" for projections: the reference's last tabulated age.
    func adultAgeMonths(for measure: GrowthMeasure, sex: ReferenceSex) -> Double?
    /// Tabulated ages, for drawing smooth curves exactly at the published points.
    func tabulatedAges(for measure: GrowthMeasure, sex: ReferenceSex) -> [Double]
}

public enum ReferenceRegistry {
    public static let cdc2000 = CDC2000Reference()

    /// Launch policy (docs/launch-strategy.md): US storefront only, CDC 2000 for everyone.
    /// Non-US references are added here only after licence checks and validation tests.
    public static func reference(forRegion regionCode: String?) -> GrowthReference {
        cdc2000
    }
}

/// Exact age in months using the CDC convention: completed days ÷ 30.4375.
public enum AgeMath {
    public static let daysPerMonth = 30.4375

    public static func days(from start: Date, to end: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0
    }

    /// Completed years (birthday-based). Used for age-band eligibility so that boundaries fall on birthdays.
    public static func completedYears(birthDate: Date, on date: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.year], from: calendar.startOfDay(for: birthDate), to: calendar.startOfDay(for: date)).year ?? 0
    }

    public static func exactAgeMonths(birthDate: Date, on date: Date, calendar: Calendar) -> Double {
        Double(days(from: birthDate, to: date, calendar: calendar)) / daysPerMonth
    }
}
