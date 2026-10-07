import Foundation
import GrowthEngine

/// Premium "advanced growth analysis": percentile history, growth speed between measurement pairs, and how the
/// adult-height estimate has moved as measurements were added. Every value is computed from stored
/// measurements with the same engine as the free screens; nothing here changes any free number.
public struct AdvancedGrowthAnalysis: Sendable, Equatable {
    public struct PercentileRow: Sendable, Equatable, Identifiable {
        public var date: Date
        public var ageMonths: Double
        public var heightCm: Double
        public var percentile: Double
        public var z: Double
        public var isEstimate: Bool
        public var id: Date { date }
    }

    public struct VelocityInterval: Sendable, Equatable, Identifiable {
        public var from: Date
        public var to: Date
        public var days: Int
        public var changeCm: Double
        public var cmPerYear: Double
        public var id: Date { to }
    }

    public struct EstimatePoint: Sendable, Equatable, Identifiable {
        public var date: Date
        public var lowCm: Double
        public var highCm: Double
        public var id: Date { date }
    }

    public var percentileHistory: [PercentileRow]
    public var velocityIntervals: [VelocityInterval]
    public var estimateHistory: [EstimatePoint]
    /// Lowest and highest percentile among careful (non-estimated) measurements.
    public var percentileRange: ClosedRange<Double>?
    public var spanMonths: Int

    public static let maximumEstimatePoints = 8

    public init(profile: GrowthProfile, now: Date, calendar: Calendar, reference: GrowthReference = ReferenceRegistry.cdc2000) {
        let analysis = GrowthAnalyzer(now: now, calendar: calendar, reference: reference).analyze(profile)
        let chartable = analysis.series.chartablePoints

        percentileHistory = chartable.compactMap { point in
            guard let p = point.percentile else { return nil }
            return PercentileRow(date: point.date, ageMonths: point.ageMonths, heightCm: point.heightCm,
                                 percentile: p.percentile, z: p.z, isEstimate: point.quality == .estimate)
        }

        let careful = percentileHistory.filter { !$0.isEstimate }
        if let lo = careful.map(\.percentile).min(), let hi = careful.map(\.percentile).max() {
            percentileRange = lo...hi
        } else {
            percentileRange = nil
        }
        if let first = careful.first, let last = careful.last {
            spanMonths = Int((Double(AgeMath.days(from: first.date, to: last.date, calendar: calendar)) / AgeMath.daysPerMonth).rounded())
        } else {
            spanMonths = 0
        }

        // Growth speed between successive measurement pairs at least ~6 months apart (same rule as the free speed).
        var intervals: [VelocityInterval] = []
        var anchor = careful.first
        for row in careful.dropFirst() {
            guard let a = anchor else { break }
            let days = AgeMath.days(from: a.date, to: row.date, calendar: calendar)
            if days >= GrowthVelocityCalculator.minimumIntervalDays {
                let change = row.heightCm - a.heightCm
                intervals.append(VelocityInterval(from: a.date, to: row.date, days: days, changeCm: change, cmPerYear: change / Double(days) * 365.25))
                anchor = row
            }
        }
        velocityIntervals = intervals

        // How the estimate looked after each measurement day, using only the data available on that day.
        var estimates: [EstimatePoint] = []
        let analyzer = { (date: Date) in GrowthAnalyzer(now: date, calendar: calendar, reference: reference) }
        for day in Set(profile.measurements.map { calendar.startOfDay(for: $0.date) }).sorted() {
            var truncated = profile
            truncated.measurements = profile.measurements.filter { calendar.startOfDay(for: $0.date) <= day }
            let endOfDay = calendar.date(byAdding: .hour, value: 23, to: day) ?? day
            if case .scenario(let s) = analyzer(endOfDay).analyze(truncated).adultHeight {
                estimates.append(EstimatePoint(date: day, lowCm: s.lowCm, highCm: s.highCm))
            }
        }
        estimateHistory = Array(estimates.suffix(Self.maximumEstimatePoints))
    }

    public var hasPattern: Bool { percentileHistory.filter { !$0.isEstimate }.count >= 2 }

    /// One factual sentence, used for the free preview and the report. Built only from stored measurements.
    public var summary: String {
        let careful = percentileHistory.filter { !$0.isEstimate }
        guard careful.count >= 2, let range = percentileRange, let zMin = careful.map(\.z).min(), let zMax = careful.map(\.z).max() else {
            return "One careful measurement on the chart so far. A pattern appears after a few more."
        }
        let span = spanMonths < 1 ? "less than a month" : (spanMonths == 1 ? "1 month" : "\(spanMonths) months")
        let lo = PercentileFormatter.ordinal(range.lowerBound)
        let hi = PercentileFormatter.ordinal(range.upperBound)
        if lo == hi { return "Over \(span), measurements have stayed at about the \(lo) percentile." }
        return zMax - zMin <= 0.5
            ? "Over \(span), measurements have stayed within a similar range, between the \(lo) and \(hi) percentiles."
            : "Over \(span), measurements have ranged from the \(lo) to the \(hi) percentile."
    }
}
