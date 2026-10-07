import Foundation

public enum MeasurementQuality: Int, Sendable, Comparable {
    case estimate = 0
    case home = 1
    case professional = 2

    public static func < (lhs: MeasurementQuality, rhs: MeasurementQuality) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// A raw measurement handed to the engine.
public struct GrowthPoint: Sendable, Equatable {
    public var date: Date
    public var heightCm: Double
    public var quality: MeasurementQuality

    public init(date: Date, heightCm: Double, quality: MeasurementQuality) {
        self.date = date
        self.heightCm = heightCm
        self.quality = quality
    }
}

/// One calendar day in the series. Several measurements on the same day are averaged into one point
/// (repeat-and-average), so same-day entries can never produce a meaningless growth speed.
public struct SeriesPoint: Sendable, Equatable, Identifiable {
    public var date: Date
    public var heightCm: Double
    /// Number of raw measurements averaged into this point.
    public var count: Int
    /// The lowest quality among the averaged measurements.
    public var quality: MeasurementQuality
    public var ageMonths: Double
    /// `nil` outside the reference's age range.
    public var percentile: PercentileResult?

    public var id: Date { date }
}

public struct GrowthSeries: Sendable, Equatable {
    public let points: [SeriesPoint]
    public let sex: ReferenceSex
    public let referenceID: String

    public init(measurements: [GrowthPoint], birthDate: Date, sex: ReferenceSex, reference: GrowthReference, calendar: Calendar) {
        let valid = measurements.filter { $0.heightCm.isFinite && $0.heightCm > 0 && $0.date >= calendar.startOfDay(for: birthDate) }
        let byDay = Dictionary(grouping: valid) { calendar.startOfDay(for: $0.date) }
        points = byDay.keys.sorted().map { day in
            let group = byDay[day]!
            let mean = group.map(\.heightCm).reduce(0, +) / Double(group.count)
            let age = AgeMath.exactAgeMonths(birthDate: birthDate, on: day, calendar: calendar)
            let percentile = try? PercentileCalculator.percentile(heightCm: mean, ageMonths: age, sex: sex, reference: reference).get()
            return SeriesPoint(date: day, heightCm: (mean * 10).rounded() / 10, count: group.count,
                               quality: group.map(\.quality).min() ?? .estimate, ageMonths: age, percentile: percentile)
        }
        self.sex = sex
        self.referenceID = reference.id
    }

    public var latest: SeriesPoint? { points.last }
    public var isEmpty: Bool { points.isEmpty }

    /// Points whose percentile is defined (inside the reference age range).
    public var chartablePoints: [SeriesPoint] { points.filter { $0.percentile != nil } }
}
