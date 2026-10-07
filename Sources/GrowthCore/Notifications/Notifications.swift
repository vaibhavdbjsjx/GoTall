import Foundation

// MARK: Preferences

/// How often to remind about measuring. Height is never requested daily.
public enum MeasurementReminderInterval: Codable, Hashable, Sendable {
    /// Every 3 months at ages 2–17, every 6 months at 18–20, none for adults (`GrowthAnalyzer.recommendedIntervalMonths`).
    case recommended
    /// A fixed number of months after the latest measurement.
    case months(Int)

    public static let customChoices = [1, 2, 3, 4, 6, 12]
}

/// Daily check-in time presets. Any other time is shown as "Custom".
public enum CheckInTimePreset: String, CaseIterable, Sendable, Identifiable {
    case morning, afternoon, evening, custom
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .custom: return "Custom"
        }
    }

    public var time: TimeOfDay? {
        switch self {
        case .morning: return TimeOfDay(hour: 8, minute: 0)
        case .afternoon: return TimeOfDay(hour: 13, minute: 0)
        case .evening: return TimeOfDay(hour: 19, minute: 0)
        case .custom: return nil
        }
    }

    public static func preset(for time: TimeOfDay) -> CheckInTimePreset {
        allCases.first { $0.time == time } ?? .custom
    }
}

/// Reminder choices, saved with the app data. Every category is opt-in and individually controllable;
/// all are off until the person turns one on.
public struct NotificationPreferences: Codable, Hashable, Sendable {
    public var measurementReminders: Bool
    public var measurementInterval: MeasurementReminderInterval
    public var dailyCheckIn: Bool
    public var dailyCheckInTime: TimeOfDay
    public var weeklySummary: Bool

    public init(measurementReminders: Bool = false, measurementInterval: MeasurementReminderInterval = .recommended,
                dailyCheckIn: Bool = false, dailyCheckInTime: TimeOfDay = TimeOfDay(hour: 19, minute: 0), weeklySummary: Bool = false) {
        self.measurementReminders = measurementReminders
        self.measurementInterval = measurementInterval
        self.dailyCheckIn = dailyCheckIn
        self.dailyCheckInTime = dailyCheckInTime
        self.weeklySummary = weeklySummary
    }

    public var anyEnabled: Bool { measurementReminders || dailyCheckIn || weeklySummary }

    public func isEnabled(_ category: NotificationCategory) -> Bool {
        switch category {
        case .measurementReminder: return measurementReminders
        case .dailyCheckIn: return dailyCheckIn
        case .weeklySummary: return weeklySummary
        }
    }

    public mutating func set(_ category: NotificationCategory, enabled: Bool) {
        switch category {
        case .measurementReminder: measurementReminders = enabled
        case .dailyCheckIn: dailyCheckIn = enabled
        case .weeklySummary: weeklySummary = enabled
        }
    }

    enum CodingKeys: String, CodingKey {
        case measurementReminders, measurementInterval, dailyCheckIn, dailyCheckInTime, weeklySummary
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        measurementReminders = try c.decodeIfPresent(Bool.self, forKey: .measurementReminders) ?? false
        measurementInterval = try c.decodeIfPresent(MeasurementReminderInterval.self, forKey: .measurementInterval) ?? .recommended
        dailyCheckIn = try c.decodeIfPresent(Bool.self, forKey: .dailyCheckIn) ?? false
        dailyCheckInTime = try c.decodeIfPresent(TimeOfDay.self, forKey: .dailyCheckInTime) ?? TimeOfDay(hour: 19, minute: 0)
        weeklySummary = try c.decodeIfPresent(Bool.self, forKey: .weeklySummary) ?? false
    }
}

public enum NotificationCategory: String, Sendable, CaseIterable {
    case measurementReminder
    case dailyCheckIn
    case weeklySummary
}

/// Where tapping a notification goes.
public enum NotificationRoute: Sendable, Equatable {
    case addMeasurement(profileID: UUID)
    case habits
    case weeklySummary

    public var encoded: String {
        switch self {
        case .addMeasurement(let id): return "measure:\(id.uuidString)"
        case .habits: return "habits"
        case .weeklySummary: return "weekly"
        }
    }

    public init?(encoded: String) {
        if encoded == "habits" { self = .habits; return }
        if encoded == "weekly" { self = .weeklySummary; return }
        if encoded.hasPrefix("measure:"), let id = UUID(uuidString: String(encoded.dropFirst(8))) { self = .addMeasurement(profileID: id); return }
        return nil
    }
}

/// One local notification the app wants to exist. Identifiers are deterministic, so the same reminder is
/// never scheduled twice: re-planning produces the same ID and replaces it instead of adding another.
public struct PlannedNotification: Sendable, Equatable, Identifiable {
    public static let idPrefix = "growth."

    public var id: String
    public var category: NotificationCategory
    public var fireDate: Date
    public var title: String
    public var body: String
    public var route: NotificationRoute

    public init(id: String, category: NotificationCategory, fireDate: Date, title: String, body: String, route: NotificationRoute) {
        self.id = id
        self.category = category
        self.fireDate = fireDate
        self.title = title
        self.body = body
        self.route = route
    }
}

// MARK: Planner

/// Turns preferences + profiles into the set of reminders that should exist right now. Pure.
///
/// - Measurement reminder: one per profile, at 10:00 when the next measurement is due (recommended or custom
///   interval after the latest measurement); tomorrow at 10:00 if it's already due. Adding a measurement moves it.
/// - Daily check-in: the next 7 days at the chosen time, one-off each, skipping today once anyone has checked in.
///   The window is refilled whenever the app is used, so after a week away the reminders stop by themselves.
/// - Weekly summary: next Sunday 18:00, only if the past week had real activity (3+ check-in days or a measurement).
/// Copy is calm and factual: no streaks, no fear, no height-gain language.
public struct NotificationPlanner: Sendable {
    public static let measurementHour = 10
    public static let dailyWindowDays = 7
    public static let weeklyMinimumCheckInDays = 3

    public var now: Date
    public var calendar: Calendar

    public init(now: Date, calendar: Calendar) {
        self.now = now
        self.calendar = calendar
    }

    public func plan(preferences: NotificationPreferences, profiles: [GrowthProfile]) -> [PlannedNotification] {
        var result: [PlannedNotification] = []
        if preferences.measurementReminders {
            for profile in profiles {
                guard let fire = nextMeasurementReminder(for: profile, interval: preferences.measurementInterval) else { continue }
                let who = profile.subject == .child ? (profile.nickname ?? "your child") : "you"
                result.append(PlannedNotification(
                    id: PlannedNotification.idPrefix + "measure." + profile.id.uuidString, category: .measurementReminder, fireDate: fire,
                    title: "Time for a height measurement",
                    body: "A new measurement for \(who) keeps the growth chart up to date. Same time of day, shoes off.",
                    route: .addMeasurement(profileID: profile.id)))
            }
        }
        if preferences.dailyCheckIn {
            let engine = HabitEngine(today: now, calendar: calendar)
            let checkedInToday = profiles.contains { !engine.completed(on: now, in: $0).isEmpty }
            let start = calendar.startOfDay(for: now)
            for offset in 0..<Self.dailyWindowDays {
                guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                      let fire = calendar.date(bySettingHour: preferences.dailyCheckInTime.hour, minute: preferences.dailyCheckInTime.minute, second: 0, of: day),
                      fire > now else { continue }
                if offset == 0 && checkedInToday { continue }
                result.append(PlannedNotification(id: PlannedNotification.idPrefix + "checkin." + dayKey(day), category: .dailyCheckIn, fireDate: fire,
                                                  title: "Daily check-in",
                                                  body: "Your daily check-in is ready.",
                                                  route: .habits))
            }
        }
        if preferences.weeklySummary, hasMeaningfulWeek(profiles) {
            var components = DateComponents()
            components.weekday = 1 // Sunday
            components.hour = 18
            components.minute = 0
            if let fire = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) {
                result.append(PlannedNotification(id: PlannedNotification.idPrefix + "weekly." + dayKey(fire), category: .weeklySummary, fireDate: fire,
                                                  title: "Your week in review",
                                                  body: "Your week in review is ready.",
                                                  route: .weeklySummary))
            }
        }
        return result.sorted { $0.fireDate < $1.fireDate }
    }

    /// The date a measurement reminder would fire for this profile, or `nil` (no measurements, or an adult
    /// on the recommended interval).
    public func nextMeasurementReminder(for profile: GrowthProfile, interval: MeasurementReminderInterval) -> Date? {
        guard let latest = profile.latestMeasurement else { return nil }
        let months: Int
        switch interval {
        case .recommended:
            guard let band = profile.age(on: now, calendar: calendar)?.band, let m = GrowthAnalyzer.recommendedIntervalMonths(for: band) else { return nil }
            months = m
        case .months(let m):
            months = max(1, m)
        }
        guard let due = calendar.date(byAdding: .month, value: months, to: calendar.startOfDay(for: latest.date)) else { return nil }
        let today = calendar.startOfDay(for: now)
        let base = due <= today ? (calendar.date(byAdding: .day, value: 1, to: today) ?? due) : due
        return calendar.date(bySettingHour: Self.measurementHour, minute: 0, second: 0, of: base)
    }

    public func hasMeaningfulWeek(_ profiles: [GrowthProfile]) -> Bool {
        profiles.contains { WeeklySummary(profile: $0, now: now, calendar: calendar).isMeaningful }
    }

    func dayKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

// MARK: Scheduling boundary

public enum NotificationAuthorization: Sendable, Equatable {
    case notDetermined, denied, authorized
}

/// A notification the system currently holds (pending).
public struct ScheduledNotification: Sendable, Equatable, Identifiable {
    public var id: String
    public var fireDate: Date?
    public var title: String
    public var body: String

    public init(id: String, fireDate: Date?, title: String, body: String) {
        self.id = id
        self.fireDate = fireDate
        self.title = title
        self.body = body
    }
}

/// The parts of `UNUserNotificationCenter` the app uses. The real implementation lives in AppFeatures;
/// tests use an in-memory fake.
public protocol NotificationScheduling: Sendable {
    func authorization() async -> NotificationAuthorization
    func requestAuthorization() async -> Bool
    func pending() async -> [ScheduledNotification]
    func schedule(_ notification: PlannedNotification) async throws
    func remove(ids: [String]) async
}

public struct NotificationSyncPlan: Sendable, Equatable {
    public var toRemove: [String]
    public var toAdd: [PlannedNotification]
}

/// Diff between what the system holds and what should exist. Only touches this app's reminders
/// (IDs starting with `PlannedNotification.idPrefix`). Unchanged reminders are left alone; changed ones
/// are replaced; stale ones (disabled category, moved date, deleted profile) are removed.
public enum NotificationReconciler {
    public static func reconcile(pending: [ScheduledNotification], desired: [PlannedNotification], calendar: Calendar) -> NotificationSyncPlan {
        let ours = pending.filter { $0.id.hasPrefix(PlannedNotification.idPrefix) }
        let desiredByID = Dictionary(desired.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var toRemove: [String] = []
        var unchanged: Set<String> = []
        var seen: Set<String> = []
        for p in ours {
            // A duplicate ID from an older version is removed so only one copy remains.
            if seen.contains(p.id) { toRemove.append(p.id); continue }
            seen.insert(p.id)
            guard let want = desiredByID[p.id] else { toRemove.append(p.id); continue }
            let sameMinute = p.fireDate.map { abs($0.timeIntervalSince(want.fireDate)) < 60 } ?? false
            if sameMinute && p.title == want.title && p.body == want.body {
                unchanged.insert(p.id)
            } else {
                toRemove.append(p.id)
            }
        }
        // Removing an ID removes every copy, so anything removed must be added back if still wanted.
        unchanged.subtract(toRemove)
        let toAdd = desired.filter { !unchanged.contains($0.id) }
        var removeUnique: [String] = []
        for id in toRemove where !removeUnique.contains(id) { removeUnique.append(id) }
        return NotificationSyncPlan(toRemove: removeUnique, toAdd: toAdd)
    }
}

// MARK: Weekly summary

/// The week in review, computed live from stored data (the notification itself carries no statistics,
/// so it can never be stale or invented).
public struct WeeklySummary: Sendable, Equatable {
    public struct HabitCount: Sendable, Equatable, Identifiable {
        public var kind: HabitKind
        public var days: Int
        public var id: String { kind.rawValue }
    }

    public var checkInDays: Int
    public var days: [HabitDayStatus]
    public var habitCounts: [HabitCount]
    public var measurementsThisWeek: Int
    public var rhythm: Int
    public var nextMeasurementDate: Date?

    public init(profile: GrowthProfile, now: Date, calendar: Calendar) {
        let engine = HabitEngine(today: now, calendar: calendar)
        days = engine.recentDays(7, in: profile)
        checkInDays = days.filter(\.checkedIn).count
        habitCounts = HabitEngine.activeHabits(for: profile).map { HabitCount(kind: $0, days: engine.weekCount(for: $0, in: profile)) }
        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        measurementsThisWeek = profile.measurements.filter { $0.date >= weekStart && $0.date <= now }.count
        rhythm = engine.rhythm(in: profile)
        nextMeasurementDate = GrowthAnalyzer(now: now, calendar: calendar).analyze(profile).nextMeasurement?.suggestedDate
    }

    /// Enough real activity for a summary to be worth sending.
    public var isMeaningful: Bool {
        checkInDays >= NotificationPlanner.weeklyMinimumCheckInDays || measurementsThisWeek > 0
    }

    public var headline: String {
        if checkInDays == 7 { return "A full week of check-ins." }
        if checkInDays == 0 && measurementsThisWeek == 0 { return "A quiet week. Continue whenever suits you." }
        return "\(checkInDays) of 7 days with a check-in."
    }
}
