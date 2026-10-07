import Foundation
import GrowthEngine

/// Everything the Home screen shows, derived only from stored data via `GrowthAnalysis`.
public struct DashboardState: Equatable, Sendable {
    public struct HeightSummary: Equatable, Sendable {
        public var value: String
        public var accessibleValue: String
        public var measuredWhen: String
        public var isEstimate: Bool
    }

    public struct ChangeSummary: Equatable, Sendable {
        /// -1 lower, 0 within ±0.5 cm, +1 higher. Drives the arrow icon.
        public var direction: Int
        public var value: String
        public var since: String
        public var accessibleValue: String
    }

    public struct PercentileSummary: Equatable, Sendable {
        /// "63rd percentile"
        public var phrase: String
        public var percentile: Double
        public var caption: String
    }

    public enum EstimateCard: Equatable, Sendable {
        /// A scenario range with its uncertainty label.
        case range(value: String, accessibleValue: String, uncertainty: UncertaintyLevel, caption: String)
        /// No range for this person (age or data); explains why.
        case message(title: String, body: String)
    }

    public struct FamilySummary: Equatable, Sendable {
        public var value: String?
        public var caption: String
    }

    public enum HabitKind: String, Sendable, CaseIterable {
        case sleep, activity, nutrition
    }

    public struct HabitBaseline: Equatable, Sendable, Identifiable {
        public var kind: HabitKind
        public var title: String
        public var value: String?
        public var id: HabitKind { kind }
    }

    public enum QuickAction: String, Sendable, CaseIterable, Identifiable {
        case measure, viewGrowth, habits
        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .measure: return "Add measurement"
            case .viewGrowth: return "View growth"
            case .habits: return "Habits"
            }
        }
        public var symbol: String {
            switch self {
            case .measure: return "ruler"
            case .viewGrowth: return "chart.xyaxis.line"
            case .habits: return "checklist"
            }
        }
    }

    public var greeting: String
    public var title: String
    public var height: HeightSummary?
    public var change: ChangeSummary?
    public var changeHint: String?
    public var percentile: PercentileSummary?
    public var percentileUnavailableReason: String?
    public var velocityText: String
    /// Short value such as "5.8 cm/yr", or nil when growth speed isn't available yet.
    public var velocityValue: String?
    public var estimate: EstimateCard
    public var family: FamilySummary?
    public var nextMeasurement: String?
    public var habits: [HabitBaseline]
    public var insight: GrowthInsight
    public var hasSafetyNote: Bool
    public var quickActions: [QuickAction]
}

public struct DashboardBuilder: Sendable {
    public var now: Date
    public var calendar: Calendar
    public var locale: Locale

    public init(now: Date, calendar: Calendar, locale: Locale = .current) {
        self.now = now
        self.calendar = calendar
        self.locale = locale
    }

    public func build(for profile: GrowthProfile) -> DashboardState {
        build(for: profile, analysis: GrowthAnalyzer(now: now, calendar: calendar).analyze(profile))
    }

    public func build(for profile: GrowthProfile, analysis: GrowthAnalysis) -> DashboardState {
        let unit = profile.unitPreference
        let points = analysis.series.points

        let height = analysis.latest.map { latest in
            DashboardState.HeightSummary(
                value: HeightFormatter.string(centimeters: latest.heightCm, unit: unit),
                accessibleValue: HeightFormatter.accessibleString(centimeters: latest.heightCm, unit: unit),
                measuredWhen: DisplayFormat.relative(latest.date, to: now, calendar: calendar),
                isEstimate: latest.quality == .estimate
            )
        }

        var change: DashboardState.ChangeSummary?
        var changeHint: String?
        if let first = points.first, let last = points.last, points.count >= 2 {
            let delta = last.heightCm - first.heightCm
            let since = DisplayFormat.monthYear(first.date, calendar: calendar, locale: locale)
            change = .init(direction: delta > 0.5 ? 1 : (delta < -0.5 ? -1 : 0),
                           value: HeightFormatter.changeString(centimeters: delta, unit: unit), since: "since " + since,
                           accessibleValue: "Changed by \(HeightFormatter.accessibleString(centimeters: abs(delta), unit: unit)) since \(since)")
        } else {
            changeHint = "Add another measurement in a few months to start seeing change over time."
        }

        var percentile: DashboardState.PercentileSummary?
        var percentileReason: String?
        if let p = analysis.currentPercentile {
            percentile = .init(phrase: PercentileFormatter.phrase(p.percentile), percentile: p.percentile,
                               caption: "On the CDC growth chart for age\(analysis.latestIsEstimate ? ", from an estimated height" : "")")
        } else {
            percentileReason = (analysis.latest?.ageMonths ?? 0) > 240 ? "Growth percentiles cover ages 2–20." : "Growth percentiles start at age 2."
        }

        let velocityText: String
        var velocityValue: String?
        switch analysis.velocity {
        case .available(let v):
            velocityText = GrowthCopy.velocitySentence(v, unit: unit)
            switch v.direction {
            case .increasing: velocityValue = GrowthCopy.speed(v.cmPerYear, unit: unit) + "/yr"
            case .littleChange: velocityValue = "Little change"
            case .decreasing: velocityValue = "Re-measure"
            }
        case .needsMoreMeasurements, .needsMoreTime:
            velocityText = GrowthCopy.velocityNeedsMore
        }

        let estimate: DashboardState.EstimateCard
        if case .scenario(let s) = analysis.adultHeight {
            estimate = .range(value: GrowthCopy.range(s.lowCm, s.highCm, unit: unit),
                              accessibleValue: GrowthCopy.accessibleRange(s.lowCm, s.highCm, unit: unit),
                              uncertainty: s.uncertainty, caption: GrowthCopy.estimateDisclaimer)
        } else if let message = GrowthCopy.outcomeMessage(analysis.adultHeight, isChild: profile.subject == .child) {
            estimate = .message(title: message.title, body: message.body)
        } else {
            estimate = .message(title: GrowthCopy.estimateTitle, body: "Add a measurement to see an estimate.")
        }

        var family: DashboardState.FamilySummary?
        switch analysis.family {
        case .available(let range):
            family = .init(value: GrowthCopy.range(range.lowCm, range.highCm, unit: unit), caption: "Context only, not a prediction")
        case .missingParentHeights:
            family = .init(value: nil, caption: "Add both parents' heights to see it")
        case .notApplicable:
            family = nil
        }

        let next = analysis.nextMeasurement.map { next in
            next.isDue ? "A new measurement is due" : "Next measurement around " + DisplayFormat.day(next.suggestedDate, calendar: calendar, locale: locale)
        }

        return DashboardState(
            greeting: greeting(),
            title: profile.subject == .child ? possessive(profile.nickname ?? "Your child") + " growth" : "Your growth",
            height: height,
            change: change,
            changeHint: changeHint,
            percentile: percentile,
            percentileUnavailableReason: percentileReason,
            velocityText: velocityText,
            velocityValue: velocityValue,
            estimate: estimate,
            family: family,
            nextMeasurement: next,
            habits: habits(for: profile),
            insight: analysis.insights.first ?? GrowthInsight(kind: .measureConsistently, symbol: "checkmark.seal", title: "Consistency beats frequency",
                                                              body: "Measuring every few months, the same way each time, shows growth most clearly."),
            hasSafetyNote: profile.intent == .concerned || !analysis.signposts.isEmpty,
            quickActions: quickActions(for: profile)
        )
    }

    func greeting() -> String {
        switch calendar.component(.hour, from: now) {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    func possessive(_ name: String) -> String {
        name.hasSuffix("s") ? name + "’" : name + "’s"
    }

    func habits(for profile: GrowthProfile) -> [DashboardState.HabitBaseline] {
        let sleepValue: String? = profile.sleep.typicalDurationMinutes.map { "About \(DisplayFormat.duration(minutes: $0)) on weeknights" }
            ?? profile.sleep.consistency?.title
        let activityParts = [profile.activity.level?.title, profile.activity.frequency.map { "\($0.title) sessions a week" }].compactMap { $0 }
        return [
            .init(kind: .sleep, title: "Sleep", value: sleepValue),
            .init(kind: .activity, title: "Activity", value: activityParts.isEmpty ? nil : activityParts.joined(separator: " · ")),
            .init(kind: .nutrition, title: "Eating", value: profile.nutrition.mealRegularity?.title ?? profile.nutrition.hydration?.title)
        ]
    }

    func quickActions(for profile: GrowthProfile) -> [DashboardState.QuickAction] {
        let habitFirst: Set<Goal> = [.healthierRoutines, .sleepConsistency, .nutritionHabits]
        if let primary = profile.primaryGoal, habitFirst.contains(primary) { return [.measure, .habits, .viewGrowth] }
        return [.measure, .viewGrowth, .habits]
    }
}
