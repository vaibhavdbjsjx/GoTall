import Foundation
import GrowthEngine

public struct GrowthInsight: Sendable, Equatable, Identifiable {
    public enum Kind: String, Sendable {
        case concernRecordKeeping, signpost, estimatedHeight, staleMeasurement, firstMeasurement, needsMoreTime,
             measurementDecrease, recentGrowth, littleChange, steadyTrajectory, percentileShift, familyContext,
             sleepConsistency, measureConsistently
    }
    public var kind: Kind
    public var symbol: String
    public var title: String
    public var body: String
    public var id: String { kind.rawValue }
}

/// Deterministic insights. Every sentence is built from stored data; nothing is invented and nothing praises
/// or judges growth ("growing perfectly", "too short"). Ordered by priority; Home shows the first.
public struct GrowthInsightEngine: Sendable {
    public var now: Date
    public var calendar: Calendar
    public var locale: Locale = .current

    public init(now: Date, calendar: Calendar, locale: Locale = .current) {
        self.now = now
        self.calendar = calendar
        self.locale = locale
    }

    func months(_ days: Int) -> Int { max(1, Int((Double(days) / 30.4375).rounded())) }
    func monthsText(_ months: Int) -> String { months == 1 ? "1 month" : "\(months) months" }

    public func insights(for profile: GrowthProfile, analysis: GrowthAnalysis) -> [GrowthInsight] {
        var result: [GrowthInsight] = []
        let unit = profile.unitPreference
        let series = analysis.series
        guard let latest = series.latest else { return result }

        if profile.intent == .concerned || !analysis.signposts.isEmpty {
            result.append(.init(kind: .concernRecordKeeping, symbol: "stethoscope", title: "A clear record helps",
                                body: "Growth varies a lot, and one measurement can't show a problem. If you're concerned, a pediatrician can review these measurements in context. Measuring the same way each time makes the record most useful."))
        }

        if latest.quality == .estimate {
            result.append(.init(kind: .estimatedHeight, symbol: "ruler", title: "Current height is an estimate",
                                body: "A careful measurement will make the growth chart and estimate more useful."))
        }

        let daysSinceLatest = AgeMath.days(from: latest.date, to: now, calendar: calendar)
        if daysSinceLatest > 183, analysis.age?.band != .adult {
            result.append(.init(kind: .staleMeasurement, symbol: "calendar.badge.clock", title: "Time for a new measurement",
                                body: "The last measurement was \(monthsText(months(daysSinceLatest))) ago. A new one will update the chart\(analysis.age?.band.isStillGrowing == true ? " and estimate" : "")."))
        }

        switch analysis.velocity {
        case .needsMoreMeasurements:
            let next = analysis.nextMeasurement.map { DisplayFormat.day($0.suggestedDate, calendar: calendar, locale: locale) }
            result.append(.init(kind: .firstMeasurement, symbol: "plus.circle", title: "One measurement so far",
                                body: "Measure again\(next.map { " around \($0)" } ?? " in a few months"), at the same time of day, to start seeing a trend."))
        case .needsMoreTime(let date):
            let span = AgeMath.days(from: series.points.first!.date, to: latest.date, calendar: calendar)
            result.append(.init(kind: .needsMoreTime, symbol: "hourglass", title: "Growth speed needs more time",
                                body: "Your measurements span \(span < 30 ? "\(span) days" : monthsText(months(span))). Growth speed needs at least 6 months between measurements, so it'll be available after \(DisplayFormat.day(date, calendar: calendar, locale: locale))."))
        case .available(let v):
            let m = monthsText(months(v.intervalDays))
            switch v.direction {
            case .increasing:
                result.append(.init(kind: .recentGrowth, symbol: "arrow.up.right", title: "Recent growth",
                                    body: "Up \(HeightFormatter.changeString(centimeters: v.changeCm, unit: unit).dropFirst()) over \(m), about \(GrowthCopy.speed(v.cmPerYear, unit: unit)) per year."))
            case .littleChange:
                result.append(.init(kind: .littleChange, symbol: "equal.circle", title: "Little change",
                                    body: "Height changed by less than half a centimetre over \(m)."
                                        + (analysis.age.map { $0.years >= 16 } == true ? " Growth often slows a lot in the late teens." : " Short pauses and measuring differences are common; the next measurement will help.")))
            case .decreasing:
                result.append(.init(kind: .measurementDecrease, symbol: "arrow.uturn.down", title: "Worth re-measuring",
                                    body: "The latest measurement is \(HeightFormatter.changeString(centimeters: abs(v.changeCm), unit: unit).dropFirst()) lower than \(m) earlier. That's almost always a measuring difference. Try measuring again carefully."))
            }
        }

        // Trajectory over the last 24 months, using measured points only.
        let window = series.chartablePoints.filter { $0.quality != .estimate && AgeMath.days(from: $0.date, to: latest.date, calendar: calendar) <= 730 }
        if let first = window.first, let last = window.last, window.count >= 2,
           let z1 = first.percentile?.z, let z2 = last.percentile?.z, let p1 = first.percentile?.percentile, let p2 = last.percentile?.percentile,
           AgeMath.days(from: first.date, to: last.date, calendar: calendar) >= 365 {
            let m = monthsText(months(AgeMath.days(from: first.date, to: last.date, calendar: calendar)))
            if abs(z2 - z1) <= 0.25, window.count >= 3 {
                result.append(.init(kind: .steadyTrajectory, symbol: "point.topleft.down.to.point.bottomright.curvepath", title: "A steady path",
                                    body: "Over \(m), height has stayed close to the \(PercentileFormatter.phrase(p2)) line."))
            } else if abs(z2 - z1) > 0.5 {
                result.append(.init(kind: .percentileShift, symbol: "arrow.left.arrow.right", title: "Percentile has shifted",
                                    body: "The percentile moved from about the \(PercentileFormatter.ordinal(p1)) to the \(PercentileFormatter.ordinal(p2)) over \(m). Shifts like this are common around puberty and can also come from measuring differences."))
            }
        }

        if case .available(let family) = analysis.family, let current = analysis.currentPercentile, let target = family.targetAdultPercentile {
            let close = abs(current.z - target.z) <= 0.5
            result.append(.init(kind: .familyContext, symbol: "person.2", title: "Family-height context",
                                body: "Current position: \(PercentileFormatter.phrase(current.percentile)). The family-height midpoint sits around the \(PercentileFormatter.phrase(target.percentile)) of adult heights. "
                                    + (close ? "These are close." : "A difference is common: family height is only one influence, and puberty timing moves percentiles.")))
        }

        if profile.goals.contains(.sleepConsistency), profile.sleep.consistency == .veryDifferent {
            result.append(.init(kind: .sleepConsistency, symbol: "moon.stars", title: "Steadier sleep",
                                body: "Sleep times vary a lot through the week. Moving toward the same wake time every day is usually easier than one big change."))
        }

        if result.isEmpty {
            result.append(.init(kind: .measureConsistently, symbol: "checkmark.seal", title: "Consistency beats frequency",
                                body: "Measuring every few months, the same way each time, shows growth more clearly than measuring often."))
        }
        return result
    }
}
