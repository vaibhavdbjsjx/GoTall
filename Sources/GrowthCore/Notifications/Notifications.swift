import Foundation

/// Reminder choices. Every category is opt-in and individually controllable.
public struct NotificationPreferences: Codable, Hashable, Sendable {
    public var measurementReminders: Bool
    public var dailyCheckIn: Bool
    public var dailyCheckInTime: TimeOfDay
    public var weeklySummary: Bool

    public init(measurementReminders: Bool = false, dailyCheckIn: Bool = false,
                dailyCheckInTime: TimeOfDay = TimeOfDay(hour: 19, minute: 0), weeklySummary: Bool = false) {
        self.measurementReminders = measurementReminders
        self.dailyCheckIn = dailyCheckIn
        self.dailyCheckInTime = dailyCheckInTime
        self.weeklySummary = weeklySummary
    }

    public var anyEnabled: Bool { measurementReminders || dailyCheckIn || weeklySummary }
}

public enum NotificationCategory: String, Sendable, CaseIterable {
    case measurementReminder
    case dailyCheckIn
    case weeklySummary
}

public struct PlannedNotification: Sendable, Equatable, Identifiable {
    public var id: String
    public var category: NotificationCategory
    public var fireDate: Date
    /// Daily/weekly reminders repeat; measurement reminders are one-off.
    public var repeats: Bool
    public var title: String
    public var body: String
}

/// Turns preferences + profiles into a reminder plan. Pure and testable; Phase 5 hands this plan to
/// UNUserNotificationCenter. Copy is calm and factual: no fear, no guilt, no streak threats.
public struct NotificationPlanner: Sendable {
    public var now: Date
    public var calendar: Calendar

    public init(now: Date, calendar: Calendar) {
        self.now = now
        self.calendar = calendar
    }

    public func plan(preferences: NotificationPreferences, profiles: [GrowthProfile]) -> [PlannedNotification] {
        var result: [PlannedNotification] = []
        if preferences.measurementReminders {
            let analyzer = GrowthAnalyzer(now: now, calendar: calendar)
            for profile in profiles {
                guard let next = analyzer.analyze(profile).nextMeasurement else { continue }
                // At 10:00 on the suggested day, or tomorrow at 10:00 if it's already due.
                let base = next.isDue ? (calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now) : next.suggestedDate
                let fire = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: base) ?? base
                let who = profile.subject == .child ? (profile.nickname ?? "your child") : "you"
                result.append(PlannedNotification(
                    id: "measure-\(profile.id.uuidString)", category: .measurementReminder, fireDate: fire, repeats: false,
                    title: "Time for a height measurement",
                    body: "A new measurement for \(who) keeps the growth chart up to date. Same time of day, shoes off."))
            }
        }
        if preferences.dailyCheckIn {
            let todayAt = calendar.date(bySettingHour: preferences.dailyCheckInTime.hour, minute: preferences.dailyCheckInTime.minute, second: 0, of: now) ?? now
            let fire = todayAt > now ? todayAt : (calendar.date(byAdding: .day, value: 1, to: todayAt) ?? todayAt)
            result.append(PlannedNotification(id: "daily-check-in", category: .dailyCheckIn, fireDate: fire, repeats: true,
                                              title: "Today's check-in",
                                              body: "A few taps to note today's habits, whenever suits you."))
        }
        if preferences.weeklySummary {
            var components = DateComponents()
            components.weekday = 1 // Sunday
            components.hour = 18
            let fire = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) ?? now
            result.append(PlannedNotification(id: "weekly-summary", category: .weeklySummary, fireDate: fire, repeats: true,
                                              title: "Your week",
                                              body: "See this week's check-ins and what's next for your growth record."))
        }
        return result
    }
}
