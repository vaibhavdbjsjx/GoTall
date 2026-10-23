import Foundation

/// The personal daily plan on Home: a short list built from the profile's goals, latest posture check, habits,
/// bedtime and measuring schedule. Deterministic for a given day, so it doesn't reshuffle while you use it.
public struct TodayPlan: Sendable, Equatable {
    public enum ItemKind: Sendable, Equatable {
        case routine(id: String)
        case habits
        case meals
        case bedtime
        case measure
        case postureCheck
    }

    public struct Item: Sendable, Equatable, Identifiable {
        public var kind: ItemKind
        public var title: String
        public var detail: String
        public var symbol: String
        public var isDone: Bool
        /// Part of Gromax Pro; shown with a Pro badge for free users.
        public var isPro: Bool

        public var id: String {
            switch kind {
            case .routine(let id): return "routine-\(id)"
            case .habits: return "habits"
            case .meals: return "meals"
            case .bedtime: return "bedtime"
            case .measure: return "measure"
            case .postureCheck: return "posture"
            }
        }
    }

    public var items: [Item]
    public var doneCount: Int { items.filter(\.isDone).count }
    public var fraction: Double { items.isEmpty ? 0 : Double(doneCount) / Double(items.count) }

    public static let postureCheckIntervalDays = 7

    public static func make(profile: GrowthProfile, analysis: GrowthAnalysis?, isPremium: Bool, today: Date, calendar: Calendar) -> TodayPlan {
        let todayStart = calendar.startOfDay(for: today)
        var items: [Item] = []

        let routine = routineOfTheDay(profile: profile, isPremium: isPremium, today: today, calendar: calendar)
        let routineDone = profile.wellness.routineSessions.contains { $0.completed && $0.routineID == routine.id && calendar.isDate($0.date, inSameDayAs: todayStart) }
        items.append(Item(kind: .routine(id: routine.id), title: routine.title, detail: "\(routine.minutes) min · \(routine.focus.title)",
                          symbol: "figure.mind.and.body", isDone: routineDone, isPro: !routine.isFree))

        let engine = HabitEngine(today: today, calendar: calendar)
        let habits = engine.status(on: todayStart, in: profile)
        if habits.total > 0 {
            items.append(Item(kind: .habits, title: "Daily habits", detail: "\(habits.completed) of \(habits.total) checked in",
                              symbol: "checklist", isDone: habits.completed == habits.total, isPro: false))
        }

        let meal = profile.wellness.meals.first { calendar.isDate($0.date, inSameDayAs: todayStart) }
        let groups = meal?.groups.count ?? 0
        items.append(Item(kind: .meals, title: "Food variety", detail: groups == 0 ? "Tap the food groups you eat today" : "\(groups) of \(FoodGroup.allCases.count) groups",
                          symbol: "fork.knife", isDone: groups >= MealLog.goodDayGroups, isPro: false))

        if let settings = profile.wellness.bedtime, let age = profile.age(on: today, calendar: calendar) {
            let plan = BedtimePlanner.plan(settings: settings, ageYears: age.years)
            items.append(Item(kind: .bedtime, title: "Bed by \(BedtimePlanner.timeText(plan.bedtimeMinutes, calendar: calendar))",
                              detail: "Wind down from \(BedtimePlanner.timeText(plan.windDownStartMinutes, calendar: calendar))",
                              symbol: "moon.stars", isDone: false, isPro: false))
        }

        if analysis?.nextMeasurement?.isDue == true {
            items.append(Item(kind: .measure, title: "Measure your height", detail: "It's time for this month's measurement",
                              symbol: "ruler", isDone: false, isPro: false))
        }

        let lastCheck = profile.wellness.latestPostureCheck
        let daysSince = lastCheck.map { calendar.dateComponents([.day], from: calendar.startOfDay(for: $0.date), to: todayStart).day ?? 0 }
        if daysSince == nil || (daysSince ?? 0) >= postureCheckIntervalDays || daysSince == 0 {
            items.append(Item(kind: .postureCheck, title: "Posture check", detail: lastCheck == nil ? "30 seconds with your front camera" : "Weekly check-in",
                              symbol: "figure.stand", isDone: daysSince == 0, isPro: lastCheck != nil))
        }
        return TodayPlan(items: items)
    }

    /// Picks today's routine: addresses the latest posture finding first, then rotates through goal-friendly
    /// routines by day of year. Free users rotate through the free routines.
    public static func routineOfTheDay(profile: GrowthProfile, isPremium: Bool, today: Date, calendar: Calendar) -> Routine {
        let pool: [Routine]
        if isPremium {
            var preferred: [Routine] = []
            if let check = profile.wellness.latestPostureCheck { preferred = RoutineLibrary.suggestions(for: check) }
            let rest = RoutineLibrary.all.filter { r in !preferred.contains { $0.id == r.id } && r.focus != .evening && r.id != "desk-break" }
            pool = preferred + rest
        } else {
            pool = RoutineLibrary.all.filter { $0.isFree && $0.focus != .evening }
        }
        let day = calendar.ordinality(of: .day, in: .year, for: today) ?? 0
        let safePool = pool.isEmpty ? RoutineLibrary.all : pool
        return safePool[day % safePool.count]
    }
}

/// Food-variety helpers. A "good day" is any three groups: simple enough to do, without counting anything.
public enum MealLog {
    public static let goodDayGroups = 3

    public static func toggling(_ group: FoodGroup, on date: Date, in profile: GrowthProfile, calendar: Calendar) -> GrowthProfile {
        var updated = profile
        let start = calendar.startOfDay(for: date)
        if let index = updated.wellness.meals.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: start) }) {
            if let g = updated.wellness.meals[index].groups.firstIndex(of: group) {
                updated.wellness.meals[index].groups.remove(at: g)
            } else {
                updated.wellness.meals[index].groups.append(group)
            }
            if updated.wellness.meals[index].groups.isEmpty { updated.wellness.meals.remove(at: index) }
        } else {
            updated.wellness.meals.append(MealDay(date: start, groups: [group]))
            updated.wellness.meals.sort { $0.date < $1.date }
        }
        if let cutoff = calendar.date(byAdding: .day, value: -400, to: start) {
            updated.wellness.meals.removeAll { $0.date < cutoff }
        }
        return updated
    }

    public static func groups(on date: Date, in profile: GrowthProfile, calendar: Calendar) -> [FoodGroup] {
        profile.wellness.meals.first { calendar.isDate($0.date, inSameDayAs: date) }?.groups ?? []
    }

    /// Days in the last 7 with at least three groups.
    public static func goodDaysThisWeek(in profile: GrowthProfile, today: Date, calendar: Calendar) -> Int {
        let start = calendar.startOfDay(for: today)
        return (0..<7).filter { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: start) else { return false }
            return groups(on: day, in: profile, calendar: calendar).count >= goodDayGroups
        }.count
    }
}
