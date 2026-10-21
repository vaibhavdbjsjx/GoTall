import Foundation

/// Points and levels earned for showing up. Computed from the logs every time (never stored), so it can't drift
/// out of sync and editing history updates it automatically. Points reward consistency, never a height change.
public struct Progression: Sendable, Equatable {
    public enum Points {
        public static let habit = 10
        public static let routine = 30
        public static let postureCheck = 20
        public static let measurement = 40
        public static let mealDay = 10
    }

    public struct Level: Sendable, Equatable {
        public var number: Int
        public var name: String
        public var floor: Int
        public var nextFloor: Int?
    }

    public var totalPoints: Int
    public var level: Level
    /// 0...1 progress toward the next level (1 at the top level).
    public var progressToNext: Double
    /// Forgiving run of active days (any habit, routine, posture check or meal log). One missed day in 7 is forgiven.
    public var activeStreak: Int
    public var activeDaysThisWeek: Int

    static let levels: [(floor: Int, name: String)] = [
        (0, "Starter"), (150, "Steady"), (400, "Consistent"), (800, "Committed"),
        (1400, "Dedicated"), (2200, "Disciplined"), (3200, "Elite"), (4500, "Legend")
    ]

    public static func level(for points: Int) -> Level {
        let index = levels.lastIndex { $0.floor <= points } ?? 0
        let next = index + 1 < levels.count ? levels[index + 1].floor : nil
        return Level(number: index + 1, name: levels[index].name, floor: levels[index].floor, nextFloor: next)
    }

    public init(profile: GrowthProfile, today: Date, calendar: Calendar) {
        let habitChecks = profile.habitLog.reduce(0) { $0 + $1.completed.count }
        let routines = profile.wellness.routineSessions.filter(\.completed).count
        let posture = profile.wellness.postureChecks.count
        // The first measurement comes from setup; later ones are the habit worth rewarding.
        let measurements = max(0, profile.measurements.count - 1)
        let meals = profile.wellness.meals.filter { $0.groups.count >= 3 }.count
        totalPoints = habitChecks * Points.habit + routines * Points.routine + posture * Points.postureCheck
            + measurements * Points.measurement + meals * Points.mealDay
        level = Self.level(for: totalPoints)
        if let next = level.nextFloor {
            progressToNext = Double(totalPoints - level.floor) / Double(next - level.floor)
        } else {
            progressToNext = 1
        }

        let todayStart = calendar.startOfDay(for: today)
        var active = Set<Date>()
        for day in profile.habitLog where !day.completed.isEmpty { active.insert(calendar.startOfDay(for: day.date)) }
        for session in profile.wellness.routineSessions where session.completed { active.insert(calendar.startOfDay(for: session.date)) }
        for check in profile.wellness.postureChecks { active.insert(calendar.startOfDay(for: check.date)) }
        for meal in profile.wellness.meals where !meal.groups.isEmpty { active.insert(calendar.startOfDay(for: meal.date)) }

        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: -offset, to: todayStart) ?? todayStart }
        activeDaysThisWeek = (0..<7).filter { active.contains(day($0)) }.count

        var offset = active.contains(todayStart) ? 0 : 1
        var count = 0
        var lastMiss: Int?
        while offset < 800 {
            if active.contains(day(offset)) {
                count += 1
            } else {
                if count == 0 { break }
                if let lastMiss, offset - lastMiss < 7 { break }
                lastMiss = offset
            }
            offset += 1
        }
        activeStreak = count
    }
}
