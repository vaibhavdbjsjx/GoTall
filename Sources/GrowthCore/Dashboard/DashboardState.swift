import Foundation

/// Everything the Home screen shows, derived only from data the person entered.
/// Placeholders say plainly that a feature is coming; nothing is simulated.
public struct DashboardState: Equatable, Sendable {
    public struct HeightSummary: Equatable, Sendable {
        public var value: String
        public var accessibleValue: String
        public var measuredWhen: String
        public var method: MeasurementMethod
    }

    public struct ChangeSummary: Equatable, Sendable {
        public var value: String
        public var since: String
        public var accessibleValue: String
    }

    public struct EstimateCard: Equatable, Sendable {
        public var availability: EstimateAvailability
        public var title: String
        public var message: String
    }

    public enum HabitKind: String, Sendable, CaseIterable {
        case sleep, activity, nutrition
    }

    public struct HabitBaseline: Equatable, Sendable, Identifiable {
        public var kind: HabitKind
        public var title: String
        /// `nil` when the person skipped this area in onboarding.
        public var value: String?
        public var id: HabitKind { kind }
    }

    public struct Insight: Equatable, Sendable {
        public var symbol: String
        public var title: String
        public var body: String
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
    public var estimate: EstimateCard
    public var percentileMessage: String
    public var habits: [HabitBaseline]
    public var insight: Insight
    public var quickActions: [QuickAction]
}

public struct DashboardBuilder: Sendable {
    public var now: Date
    public var calendar: Calendar
    public var locale: Locale
    public var estimator: GrowthEstimating

    public init(now: Date, calendar: Calendar, locale: Locale = .current, estimator: GrowthEstimating = PendingGrowthEstimator()) {
        self.now = now
        self.calendar = calendar
        self.locale = locale
        self.estimator = estimator
    }

    public func build(for profile: GrowthProfile) -> DashboardState {
        let unit = profile.unitPreference
        let measurements = profile.sortedMeasurements

        let height = measurements.last.map { latest in
            DashboardState.HeightSummary(
                value: HeightFormatter.string(centimeters: latest.heightCm, unit: unit),
                accessibleValue: HeightFormatter.accessibleString(centimeters: latest.heightCm, unit: unit),
                measuredWhen: DisplayFormat.relative(latest.date, to: now, calendar: calendar),
                method: latest.method
            )
        }

        var change: DashboardState.ChangeSummary?
        var changeHint: String?
        if let first = measurements.first, let last = measurements.last, measurements.count >= 2 {
            let delta = last.heightCm - first.heightCm
            change = DashboardState.ChangeSummary(
                value: HeightFormatter.changeString(centimeters: delta, unit: unit),
                since: "since " + DisplayFormat.monthYear(first.date, calendar: calendar, locale: locale),
                accessibleValue: "Changed by \(HeightFormatter.accessibleString(centimeters: abs(delta), unit: unit)) since \(DisplayFormat.monthYear(first.date, calendar: calendar, locale: locale))"
            )
        } else {
            changeHint = "Add another measurement in a few weeks to start seeing change over time."
        }

        let availability = estimator.availability(for: profile, on: now, calendar: calendar)
        let isAdult = availability == .adult

        return DashboardState(
            greeting: greeting(),
            title: profile.subject == .child ? possessive(profile.nickname ?? "Your child") + " growth" : "Your growth",
            height: height,
            change: change,
            changeHint: changeHint,
            estimate: estimateCard(availability),
            percentileMessage: isAdult
                ? "Growth percentiles cover ages 2–20."
                : "Your position on the CDC growth chart is coming in the next update.",
            habits: habits(for: profile),
            insight: InsightEngine.insight(for: profile, measurements: measurements),
            quickActions: quickActions(for: profile)
        )
    }

    func greeting() -> String {
        let hour = calendar.component(.hour, from: now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    func possessive(_ name: String) -> String {
        name.hasSuffix("s") ? name + "’" : name + "’s"
    }

    func estimateCard(_ availability: EstimateAvailability) -> DashboardState.EstimateCard {
        switch availability {
        case .engineNotAvailable:
            return .init(availability: availability, title: "Adult height range",
                         message: "Coming in the next update: a height range with its method and limits explained. We'd rather show nothing than a guess.")
        case .chartOnlyAge:
            return .init(availability: availability, title: "Adult height range",
                         message: "Estimates start at age 4. Until then, measurements build the growth chart.")
        case .nearAdult:
            return .init(availability: availability, title: "Near adult height",
                         message: "Most growth is complete by now. Keep measuring every few months to see whether height is still changing.")
        case .adult:
            return .init(availability: availability, title: "Adult height",
                         message: "Your measured height is your adult height, so there's nothing to estimate.")
        }
    }

    func habits(for profile: GrowthProfile) -> [DashboardState.HabitBaseline] {
        let sleepValue: String? = {
            if let minutes = profile.sleep.typicalDurationMinutes {
                return "About \(DisplayFormat.duration(minutes: minutes)) on weeknights"
            }
            return profile.sleep.consistency?.title
        }()
        let activityValue: String? = {
            let parts = [profile.activity.level?.title, profile.activity.frequency.map { "\($0.title) sessions a week" }].compactMap { $0 }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }()
        let nutritionValue: String? = profile.nutrition.mealRegularity?.title ?? profile.nutrition.hydration?.title
        return [
            .init(kind: .sleep, title: "Sleep", value: sleepValue),
            .init(kind: .activity, title: "Activity", value: activityValue),
            .init(kind: .nutrition, title: "Eating", value: nutritionValue)
        ]
    }

    func quickActions(for profile: GrowthProfile) -> [DashboardState.QuickAction] {
        let habitFirst: Set<Goal> = [.healthierRoutines, .sleepConsistency, .nutritionHabits]
        if let primary = profile.primaryGoal, habitFirst.contains(primary) {
            return [.measure, .habits, .viewGrowth]
        }
        return [.measure, .viewGrowth, .habits]
    }
}

/// One rule-based tip at a time, chosen from what the person told us. Guidance only; no numbers are invented.
public enum InsightEngine {
    public static func insight(for profile: GrowthProfile, measurements: [HeightMeasurement]) -> DashboardState.Insight {
        if profile.intent == .concerned {
            return .init(symbol: "stethoscope", title: "A clear record helps",
                         body: "Measure the same way each time. A consistent record is the most useful thing to bring to a doctor.")
        }
        if measurements.last?.method == .estimate {
            return .init(symbol: "ruler", title: "Swap the estimate for a measurement",
                         body: "The current height is an estimate. A careful wall measurement makes everything here more reliable.")
        }
        if measurements.count == 1 {
            return .init(symbol: "calendar.badge.clock", title: "The trend starts with your next measurement",
                         body: "Measure again in about a month, at the same time of day. Change over months means more than day-to-day differences.")
        }
        if profile.goals.contains(.sleepConsistency), profile.sleep.consistency == .veryDifferent {
            return .init(symbol: "moon.stars", title: "Steadier sleep",
                         body: "Sleep times vary a lot through the week. Moving toward the same wake time every day is usually easier than one big change.")
        }
        return .init(symbol: "checkmark.seal", title: "Consistency beats frequency",
                     body: "Measuring every month or two, the same way each time, shows growth more clearly than measuring often.")
    }
}
