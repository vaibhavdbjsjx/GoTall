import Foundation
import GrowthEngine

/// A short, data-justified headline for Home. Never more positive than the data supports.
public enum GrowthStatus: Sendable, Equatable {
    /// Growth speed available and increasing, and a steady percentile path (≥ 3 measured points over ≥ 12 months).
    case growingSteadily
    /// Growth speed available and increasing.
    case growing
    /// Less than ±0.5 cm over at least 6 months.
    case littleChange
    /// The latest measurement is lower: likely a measuring difference.
    case worthRemeasuring
    /// Not enough history yet for growth speed.
    case buildingHistory
    /// 21+.
    case adultHeight

    public var title: String {
        switch self {
        case .growingSteadily: return "Growing steadily"
        case .growing: return "Growing"
        case .littleChange: return "Little change recently"
        case .worthRemeasuring: return "Worth re-measuring"
        case .buildingHistory: return "Building your growth history"
        case .adultHeight: return "Adult height"
        }
    }

    public var symbol: String {
        switch self {
        case .growingSteadily: return "point.topleft.down.to.point.bottomright.curvepath"
        case .growing: return "arrow.up.right"
        case .littleChange: return "equal"
        case .worthRemeasuring: return "ruler"
        case .buildingHistory: return "square.stack.3d.up"
        case .adultHeight: return "checkmark.circle"
        }
    }

    public static func from(_ analysis: GrowthAnalysis) -> GrowthStatus {
        if analysis.age?.band == .adult { return .adultHeight }
        guard case .available(let v) = analysis.velocity else { return .buildingHistory }
        switch v.direction {
        case .decreasing: return .worthRemeasuring
        case .littleChange: return .littleChange
        case .increasing:
            return analysis.insights.contains { $0.kind == .steadyTrajectory } ? .growingSteadily : .growing
        }
    }
}

/// The single most useful next step. Chosen deterministically from stored data.
public struct NextAction: Sendable, Equatable {
    public enum Kind: String, Sendable {
        case measureNow, checkIn, addParentHeights, measureLater, reviewGrowth
    }
    public var kind: Kind
    public var title: String
    public var detail: String
    public var symbol: String
    /// False for purely informational actions (nothing to tap now).
    public var isActionable: Bool
}

public enum NextActionEngine {
    public static func next(profile: GrowthProfile, analysis: GrowthAnalysis, now: Date, calendar: Calendar, locale: Locale = .current) -> NextAction {
        if let next = analysis.nextMeasurement, next.isDue {
            return NextAction(kind: .measureNow, title: "Add a measurement",
                              detail: "It's been a while. A new measurement updates the chart and estimate.", symbol: "ruler", isActionable: true)
        }
        let habits = HabitEngine(today: now, calendar: calendar)
        let today = habits.status(on: now, in: profile)
        if today.total > 0, today.completed < today.total {
            let left = today.total - today.completed
            return NextAction(kind: .checkIn, title: "Today's check-in",
                              detail: left == today.total ? "\(today.total) quick habits to note for today." : "\(left) more to note for today.",
                              symbol: "checklist", isActionable: true)
        }
        if case .missingParentHeights = analysis.family {
            return NextAction(kind: .addParentHeights, title: "Add family height",
                              detail: "Both parents' heights add useful context to the growth picture.", symbol: "person.2", isActionable: true)
        }
        if let next = analysis.nextMeasurement {
            return NextAction(kind: .measureLater, title: "Next measurement",
                              detail: "Around \(DisplayFormat.day(next.suggestedDate, calendar: calendar, locale: locale)). Every few months is plenty.",
                              symbol: "calendar", isActionable: false)
        }
        return NextAction(kind: .reviewGrowth, title: "Review your growth history",
                          detail: "See every measurement on the chart.", symbol: "chart.xyaxis.line", isActionable: true)
    }
}

/// What changed after saving a measurement: celebrates better data, not height gained.
public struct MeasurementOutcome: Sendable, Equatable {
    public var headline: String
    public var detail: String
    public var percentileText: String?
    public var measurementDays: Int

    public static func compare(before: GrowthAnalysis, after: GrowthAnalysis) -> MeasurementOutcome {
        let percentile = after.currentPercentile.map { PercentileFormatter.phrase($0.percentile) }
        let days = after.series.points.count
        let speedBefore: Bool = { if case .available = before.velocity { return true }; return false }()
        let speedAfter: Bool = { if case .available = after.velocity { return true }; return false }()
        if !speedBefore && speedAfter {
            return .init(headline: "Growth speed is now available",
                         detail: "With measurements far enough apart, your growth history just became more informative.",
                         percentileText: percentile, measurementDays: days)
        }
        if before.series.points.count == 1 && days == 2 {
            return .init(headline: "Your trend has started",
                         detail: "Two measurements make a line on the chart. Growth speed needs at least 6 months between them.",
                         percentileText: percentile, measurementDays: days)
        }
        if days == before.series.points.count {
            return .init(headline: "Measurement saved",
                         detail: "It was averaged with another measurement from the same day.",
                         percentileText: percentile, measurementDays: days)
        }
        return .init(headline: "Measurement saved",
                     detail: "Your chart and analysis are up to date. Consistent measuring makes the picture clearer.",
                     percentileText: percentile, measurementDays: days)
    }
}

/// One-line summary for profile pickers.
public struct ProfileCardSummary: Sendable, Equatable {
    public var name: String
    public var ageText: String
    public var heightText: String?
    public var statusText: String

    public init(profile: GrowthProfile, now: Date, calendar: Calendar) {
        name = profile.subject == .myself ? "Me" : (profile.nickname ?? "Child")
        ageText = profile.age(on: now, calendar: calendar).map { "\($0.years) years" } ?? ""
        heightText = profile.latestMeasurement.map { HeightFormatter.string(centimeters: $0.heightCm, unit: profile.unitPreference) }
        statusText = GrowthStatus.from(GrowthAnalyzer(now: now, calendar: calendar).analyze(profile)).title
    }
}

/// JSON export of everything stored on the device (data ownership).
public enum DataExporter {
    public static func exportJSON(_ snapshot: AppSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    public static func fileName(now: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        return String(format: "growth-data-%04d-%02d-%02d.json", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
