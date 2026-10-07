import Foundation

/// Daily habits for healthy development. They never affect any height number (see docs/growth-engine.md §7.4).
/// Check-ins are self-reported yes/no; no calories, no weight, no numeric targets for minors.
public enum HabitKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case sleep
    case activity
    case meals
    case hydration

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .sleep: return "Sleep routine"
        case .activity: return "Active time"
        case .meals: return "Regular meals"
        case .hydration: return "Water"
        }
    }

    /// The check-in question, answered yes for today.
    public var prompt: String {
        switch self {
        case .sleep: return "Kept to my usual bedtime"
        case .activity: return "Got some active time today"
        case .meals: return "Had regular meals"
        case .hydration: return "Drank water through the day"
        }
    }

    public var symbol: String {
        switch self {
        case .sleep: return "moon.stars"
        case .activity: return "figure.run"
        case .meals: return "fork.knife"
        case .hydration: return "drop"
        }
    }

    /// Why this habit is here, in calm, non-promissory language.
    public var why: String {
        switch self {
        case .sleep: return "A steady sleep routine supports overall health, mood and recovery."
        case .activity: return "Regular movement supports fitness, strong bones and wellbeing."
        case .meals: return "Regular, varied meals give the body what it needs for healthy development."
        case .hydration: return "Drinking water through the day is an easy healthy habit."
        }
    }
}

public struct HabitDay: Codable, Hashable, Sendable {
    /// Start of the calendar day.
    public var date: Date
    public var completed: [HabitKind]

    public init(date: Date, completed: [HabitKind]) {
        self.date = date
        self.completed = completed
    }
}

public struct HabitDayStatus: Sendable, Equatable, Identifiable {
    public var date: Date
    public var completed: Int
    public var total: Int
    public var isToday: Bool
    public var id: Date { date }
    public var fraction: Double { total == 0 ? 0 : Double(completed) / Double(total) }
    public var checkedIn: Bool { completed > 0 }
}

/// Forgiving-consistency engine. Definitions (also shown to users where a number appears):
/// - **Check-in day:** a day with at least one habit completed.
/// - **This week:** the last 7 days including today ("4 of 7 days").
/// - **Rhythm:** check-in days in the current run, where one missed day in any 7 is forgiven and today
///   doesn't count as missed until it's over. Missing more simply starts a new run; nothing is "broken".
public struct HabitEngine: Sendable {
    public var today: Date
    public var calendar: Calendar
    /// How many days back a check-in can still be added or removed.
    public static let editableDays = 6
    public static let maximumActive = 4
    public static let defaultActiveCount = 3

    public init(today: Date, calendar: Calendar) {
        self.today = today
        self.calendar = calendar
    }

    var todayStart: Date { calendar.startOfDay(for: today) }

    func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: -offset, to: todayStart) ?? todayStart
    }

    // MARK: Active habits

    /// Defaults follow goals: the goal-linked habit first, then the general order, up to 3.
    public static func defaultHabits(for profile: GrowthProfile) -> [HabitKind] {
        var ordered: [HabitKind] = []
        for goal in profile.goals {
            switch goal {
            case .sleepConsistency: ordered.append(.sleep)
            case .nutritionHabits: ordered.append(.meals)
            case .healthierRoutines: ordered.append(.activity)
            default: break
            }
        }
        for kind in [HabitKind.sleep, .activity, .meals, .hydration] where !ordered.contains(kind) {
            ordered.append(kind)
        }
        var unique: [HabitKind] = []
        for kind in ordered where !unique.contains(kind) { unique.append(kind) }
        return Array(unique.prefix(defaultActiveCount))
    }

    public static func activeHabits(for profile: GrowthProfile) -> [HabitKind] {
        let chosen = profile.activeHabits ?? defaultHabits(for: profile)
        return Array(chosen.prefix(maximumActive))
    }

    // MARK: Reading

    public func completed(on date: Date, in profile: GrowthProfile) -> [HabitKind] {
        let start = calendar.startOfDay(for: date)
        let active = Self.activeHabits(for: profile)
        return profile.habitLog.first { calendar.isDate($0.date, inSameDayAs: start) }?.completed.filter(active.contains) ?? []
    }

    public func isCompleted(_ kind: HabitKind, on date: Date, in profile: GrowthProfile) -> Bool {
        completed(on: date, in: profile).contains(kind)
    }

    public func isEditable(_ date: Date) -> Bool {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: todayStart).day ?? 0
        return days >= 0 && days <= Self.editableDays
    }

    // MARK: Writing

    /// Toggles a habit for a day. Future days and days older than a week are ignored.
    public func toggling(_ kind: HabitKind, on date: Date, in profile: GrowthProfile) -> GrowthProfile {
        guard isEditable(date) else { return profile }
        var updated = profile
        let start = calendar.startOfDay(for: date)
        if let index = updated.habitLog.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: start) }) {
            if let k = updated.habitLog[index].completed.firstIndex(of: kind) {
                updated.habitLog[index].completed.remove(at: k)
            } else {
                updated.habitLog[index].completed.append(kind)
            }
            if updated.habitLog[index].completed.isEmpty { updated.habitLog.remove(at: index) }
        } else {
            updated.habitLog.append(HabitDay(date: start, completed: [kind]))
            updated.habitLog.sort { $0.date < $1.date }
        }
        // Keep storage bounded: a year of history is plenty for consistency views.
        if let cutoff = calendar.date(byAdding: .day, value: -400, to: todayStart) {
            updated.habitLog.removeAll { $0.date < cutoff }
        }
        return updated
    }

    // MARK: Summaries

    public func status(on date: Date, in profile: GrowthProfile) -> HabitDayStatus {
        HabitDayStatus(date: calendar.startOfDay(for: date), completed: completed(on: date, in: profile).count,
                       total: Self.activeHabits(for: profile).count, isToday: calendar.isDate(date, inSameDayAs: todayStart))
    }

    /// Last `days` days, oldest first, ending today.
    public func recentDays(_ days: Int, in profile: GrowthProfile) -> [HabitDayStatus] {
        (0..<days).reversed().map { status(on: day($0), in: profile) }
    }

    public func checkInDaysThisWeek(in profile: GrowthProfile) -> Int {
        recentDays(7, in: profile).filter(\.checkedIn).count
    }

    public func weekCount(for kind: HabitKind, in profile: GrowthProfile) -> Int {
        (0..<7).filter { isCompleted(kind, on: day($0), in: profile) }.count
    }

    /// Forgiving run of check-in days (see type documentation).
    public func rhythm(in profile: GrowthProfile) -> Int {
        let checked = Set(profile.habitLog.filter { !$0.completed.isEmpty }.map { calendar.startOfDay(for: $0.date) })
        var offset = checked.contains(todayStart) ? 0 : 1
        var count = 0
        var missOffsets: [Int] = []
        while offset < 800 {
            let date = day(offset)
            if checked.contains(date) {
                count += 1
            } else {
                if let lastMiss = missOffsets.last, lastMiss - offset > -7 { break }
                missOffsets.append(offset)
                // A run can't start with a forgiven miss.
                if count == 0 { break }
            }
            offset += 1
        }
        return count
    }

    public func daysSinceLastCheckIn(in profile: GrowthProfile) -> Int? {
        guard let last = profile.habitLog.filter({ !$0.completed.isEmpty }).map(\.date).max() else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: todayStart).day
    }

    /// Calm message for the top of Habits. Never mentions failure.
    public func encouragement(in profile: GrowthProfile) -> String {
        let todayDone = status(on: todayStart, in: profile)
        if let since = daysSinceLastCheckIn(in: profile), since >= 2, !todayDone.checkedIn {
            return "You're back. Continue from today."
        }
        if profile.habitLog.isEmpty { return "Small, steady routines add up. Start with one today." }
        if todayDone.total > 0 && todayDone.completed == todayDone.total { return "All of today's habits are done." }
        let week = checkInDaysThisWeek(in: profile)
        return week == 7 ? "A full week of check-ins." : "\(week) of 7 days this week."
    }

    /// The habit with the most check-ins over 14 days, once there's enough data (≥ 5 check-in days).
    public func mostConsistent(in profile: GrowthProfile) -> (kind: HabitKind, days: Int)? {
        let days = (0..<14).map { day($0) }
        guard days.filter({ !completed(on: $0, in: profile).isEmpty }).count >= 5 else { return nil }
        let counts = Self.activeHabits(for: profile).map { kind in (kind, days.filter { isCompleted(kind, on: $0, in: profile) }.count) }
        return counts.max { $0.1 < $1.1 }.map { (kind: $0.0, days: $0.1) }
    }
}
