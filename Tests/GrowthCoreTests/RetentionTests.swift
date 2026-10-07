import XCTest
import GrowthEngine
@testable import GrowthCore

final class HabitEngineTests: XCTestCase {
    let engine = HabitEngine(today: T.today, calendar: T.calendar)

    func profile(goals: [Goal] = [], log: [HabitDay] = [], active: [HabitKind]? = nil) -> GrowthProfile {
        GrowthProfile(subject: .myself, birthDate: T.date(2011, 3, 15), chartSex: .female, unitPreference: .centimeters,
                      measurements: [HeightMeasurement(date: T.date(2026, 10, 1), heightCm: 158, method: .home, origin: .manual)],
                      goals: goals, habitLog: log, activeHabits: active, createdAt: T.today, updatedAt: T.today)
    }

    func daysAgo(_ n: Int) -> Date { T.calendar.date(byAdding: .day, value: -n, to: T.calendar.startOfDay(for: T.today))! }

    /// A log with all default habits completed on the given day offsets.
    func log(_ offsets: [Int], habits: [HabitKind] = [.sleep, .activity, .meals]) -> [HabitDay] {
        offsets.map { HabitDay(date: daysAgo($0), completed: habits) }.sorted { $0.date < $1.date }
    }

    func testDefaultsFollowGoals() {
        XCTAssertEqual(HabitEngine.defaultHabits(for: profile()), [.sleep, .activity, .meals])
        XCTAssertEqual(HabitEngine.defaultHabits(for: profile(goals: [.nutritionHabits, .sleepConsistency])), [.meals, .sleep, .activity])
        XCTAssertEqual(HabitEngine.activeHabits(for: profile(active: [.hydration])), [.hydration])
        XCTAssertEqual(HabitEngine.activeHabits(for: profile(active: HabitKind.allCases + HabitKind.allCases)).count, 4)
    }

    func testToggleOnAndOff() {
        var p = engine.toggling(.sleep, on: T.today, in: profile())
        XCTAssertTrue(engine.isCompleted(.sleep, on: T.today, in: p))
        XCTAssertEqual(p.habitLog.count, 1)
        p = engine.toggling(.sleep, on: T.today, in: p)
        XCTAssertFalse(engine.isCompleted(.sleep, on: T.today, in: p))
        XCTAssertTrue(p.habitLog.isEmpty, "Empty days are removed")
    }

    func testOnlyRecentPastDaysAreEditable() {
        XCTAssertTrue(engine.isEditable(T.today))
        XCTAssertTrue(engine.isEditable(daysAgo(6)))
        XCTAssertFalse(engine.isEditable(daysAgo(7)))
        XCTAssertFalse(engine.isEditable(T.calendar.date(byAdding: .day, value: 1, to: T.today)!))
        let p = engine.toggling(.sleep, on: daysAgo(10), in: profile())
        XCTAssertTrue(p.habitLog.isEmpty)
    }

    func testInactiveHabitsDontCount() {
        let p = profile(log: [HabitDay(date: daysAgo(0), completed: [.hydration])])
        XCTAssertEqual(engine.status(on: T.today, in: p).completed, 0, "Hydration isn't an active default habit")
    }

    func testWeeklyConsistency() {
        let p = profile(log: log([0, 1, 3, 5]))
        XCTAssertEqual(engine.checkInDaysThisWeek(in: p), 4)
        XCTAssertEqual(engine.weekCount(for: .sleep, in: p), 4)
        XCTAssertEqual(engine.recentDays(7, in: p).count, 7)
        XCTAssertTrue(engine.recentDays(7, in: p).last!.isToday)
        XCTAssertEqual(engine.encouragement(in: p), "All of today's habits are done.")
    }

    func testRhythmForgivesOneMissedDayInSeven() {
        // Checked in today, 1, 2, missed 3, checked 4–8 → one miss forgiven: 8 check-in days.
        XCTAssertEqual(engine.rhythm(in: profile(log: log([0, 1, 2, 4, 5, 6, 7, 8]))), 8)
    }

    func testTwoMissesWithinSevenDaysStartANewRun() {
        // Missed days 2 and 4 (within 7 days of each other) → run is today + yesterday + day 3.
        XCTAssertEqual(engine.rhythm(in: profile(log: log([0, 1, 3, 5, 6, 7]))), 3)
    }

    func testTodayNotYetCheckedInIsNotAMiss() {
        XCTAssertEqual(engine.rhythm(in: profile(log: log([1, 2, 3]))), 3)
    }

    func testReturningAfterABreakIsWelcomedNotShamed() {
        let p = profile(log: log([4, 5, 6]))
        XCTAssertEqual(engine.rhythm(in: p), 0)
        XCTAssertEqual(engine.encouragement(in: p), "You're back. Continue from today.")
        XCTAssertEqual(CopyGuard.violations(in: engine.encouragement(in: p)), [])
        XCTAssertFalse(engine.encouragement(in: p).lowercased().contains("broke"))
    }

    func testMostConsistentNeedsEnoughData() {
        XCTAssertNil(engine.mostConsistent(in: profile(log: log([0, 1]))))
        let p = profile(log: log([0, 1, 2, 3], habits: [.sleep]) + log([5, 6], habits: [.sleep, .activity]))
        XCTAssertEqual(engine.mostConsistent(in: p)?.kind, .sleep)
    }

    func testHabitsNeverChangeHeightAnalysis() {
        let analyzer = GrowthAnalyzer(now: T.today, calendar: T.calendar)
        let before = analyzer.analyze(profile())
        let after = analyzer.analyze(profile(log: log(Array(0..<30), habits: HabitKind.allCases)))
        XCTAssertEqual(before.adultHeight, after.adultHeight)
        XCTAssertEqual(before.series, after.series)
    }

    func testRepositoryToggleAndActiveHabits() {
        let p = profile()
        MainActor.assumeIsolated {
            let (repository, _) = T.repository()
            repository.completeOnboarding(with: p)
            repository.toggleHabit(.activity, on: T.today, for: p.id, today: T.today, calendar: T.calendar)
            XCTAssertEqual(repository.activeProfile?.habitLog.first?.completed, [.activity])
            repository.setActiveHabits([.hydration, .sleep], for: p.id)
            XCTAssertEqual(repository.activeProfile?.activeHabits, [.hydration, .sleep])
        }
    }
}

final class NotificationPlannerTests: XCTestCase {
    let planner = NotificationPlanner(now: T.today, calendar: T.calendar) // 2026-10-07 10:00 UTC

    func profile(measured: Date) -> GrowthProfile {
        GrowthProfile(subject: .child, nickname: "Ava", birthDate: T.date(2016, 1, 1), chartSex: .female, unitPreference: .centimeters,
                      measurements: [HeightMeasurement(date: measured, heightCm: 135, method: .home, origin: .manual)], createdAt: T.today, updatedAt: T.today)
    }

    func testNothingWhenAllOff() {
        XCTAssertEqual(planner.plan(preferences: NotificationPreferences(), profiles: [profile(measured: T.today)]), [])
        XCTAssertFalse(NotificationPreferences().anyEnabled)
    }

    func testMeasurementReminderAtSuggestedDate() {
        let plan = planner.plan(preferences: NotificationPreferences(measurementReminders: true), profiles: [profile(measured: T.date(2026, 9, 1))])
        XCTAssertEqual(plan.count, 1)
        XCTAssertEqual(plan[0].category, .measurementReminder)
        XCTAssertEqual(plan[0].fireDate, T.calendar.date(from: DateComponents(year: 2026, month: 12, day: 1, hour: 10))!)
        XCTAssertTrue(plan[0].body.contains("Ava"))
        XCTAssertFalse(plan[0].repeats)
    }

    func testDueReminderFiresTomorrowMorning() {
        let plan = planner.plan(preferences: NotificationPreferences(measurementReminders: true), profiles: [profile(measured: T.date(2026, 1, 1))])
        XCTAssertEqual(plan[0].fireDate, T.calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 10))!)
    }

    func testDailyAndWeekly() {
        let prefs = NotificationPreferences(dailyCheckIn: true, dailyCheckInTime: TimeOfDay(hour: 8, minute: 0), weeklySummary: true)
        let plan = planner.plan(preferences: prefs, profiles: [])
        let daily = plan.first { $0.category == .dailyCheckIn }!
        XCTAssertEqual(daily.fireDate, T.calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 8))!, "08:00 already passed today")
        XCTAssertTrue(daily.repeats)
        let weekly = plan.first { $0.category == .weeklySummary }!
        XCTAssertEqual(T.calendar.component(.weekday, from: weekly.fireDate), 1)
        XCTAssertGreaterThan(weekly.fireDate, T.today)
    }

    func testCopyIsCalm() {
        let prefs = NotificationPreferences(measurementReminders: true, dailyCheckIn: true, weeklySummary: true)
        for n in planner.plan(preferences: prefs, profiles: [profile(measured: T.date(2026, 9, 1))]) {
            let text = (n.title + " " + n.body).lowercased()
            XCTAssertEqual(CopyGuard.violations(in: text), [])
            for fear in ["losing", "lose", "streak", "don't miss", "hurry", "last chance"] { XCTAssertFalse(text.contains(fear), text) }
        }
    }

    func testPreferencesPersistAndOldFilesDecode() throws {
        let store = try T.makeFileStore()
        MainActor.assumeIsolated {
            let repository = AppRepository(store: store)
            repository.setNotificationPreferences(NotificationPreferences(dailyCheckIn: true))
        }
        guard case .loaded(let loaded) = store.load() else { return XCTFail() }
        XCTAssertTrue(loaded.notificationPreferences.dailyCheckIn)
        let old = try FileProfileStore.makeDecoder().decode(AppSnapshot.self, from: Data("{\"profiles\":[]}".utf8))
        XCTAssertEqual(old.notificationPreferences, NotificationPreferences())
    }
}

final class HomeModelTests: XCTestCase {
    let analyzer = GrowthAnalyzer(now: T.today, calendar: T.calendar)

    func profile(birth: Date = T.date(2012, 4, 1), _ ms: [(Date, Double)], parents: Bool = false, log: [HabitDay] = []) -> GrowthProfile {
        GrowthProfile(subject: .myself, birthDate: birth, chartSex: .male, unitPreference: .centimeters,
                      measurements: ms.map { HeightMeasurement(date: $0.0, heightCm: $0.1, method: .home, origin: .manual) },
                      parentHeights: parents ? ParentHeights(mother: .known(heightCm: 165, source: .measured), father: .known(heightCm: 180, source: .measured)) : ParentHeights(),
                      habitLog: log, createdAt: T.today, updatedAt: T.today)
    }

    func testGrowthStatusIsNeverMorePositiveThanData() {
        XCTAssertEqual(GrowthStatus.from(analyzer.analyze(profile([(T.date(2026, 9, 1), 157)]))), .buildingHistory)
        XCTAssertEqual(GrowthStatus.from(analyzer.analyze(profile([(T.date(2025, 9, 1), 150), (T.date(2026, 9, 1), 157)]))), .growing)
        XCTAssertEqual(GrowthStatus.from(analyzer.analyze(profile([(T.date(2025, 9, 1), 157), (T.date(2026, 9, 1), 157.2)]))), .littleChange)
        XCTAssertEqual(GrowthStatus.from(analyzer.analyze(profile([(T.date(2025, 9, 1), 157), (T.date(2026, 9, 1), 155)]))), .worthRemeasuring)
        XCTAssertEqual(GrowthStatus.from(analyzer.analyze(profile(birth: T.date(1990, 1, 1), [(T.date(2026, 9, 1), 178)]))), .adultHeight)
    }

    func testGrowingSteadilyRequiresSteadyPath() {
        let birth = T.date(2012, 4, 1)
        func h(_ z: Double, _ d: Date) -> Double {
            PercentileCalculator.height(atZ: z, ageMonths: AgeMath.exactAgeMonths(birthDate: birth, on: d, calendar: T.calendar), sex: .male, reference: ReferenceRegistry.cdc2000)!
        }
        let dates = [T.date(2025, 3, 1), T.date(2025, 9, 1), T.date(2026, 9, 1)]
        XCTAssertEqual(GrowthStatus.from(analyzer.analyze(profile(dates.map { ($0, h(0.3, $0)) }))), .growingSteadily)
    }

    func testNextActionPriorities() {
        // Due measurement wins.
        let due = profile([(T.date(2026, 1, 1), 150)])
        XCTAssertEqual(NextActionEngine.next(profile: due, analysis: analyzer.analyze(due), now: T.today, calendar: T.calendar).kind, .measureNow)
        // Not due, habits pending → check-in.
        let recent = profile([(T.date(2026, 9, 20), 157)])
        XCTAssertEqual(NextActionEngine.next(profile: recent, analysis: analyzer.analyze(recent), now: T.today, calendar: T.calendar).kind, .checkIn)
        // Habits done, parents missing → add family height.
        let done = profile([(T.date(2026, 9, 20), 157)], log: [HabitDay(date: T.calendar.startOfDay(for: T.today), completed: [.sleep, .activity, .meals])])
        XCTAssertEqual(NextActionEngine.next(profile: done, analysis: analyzer.analyze(done), now: T.today, calendar: T.calendar).kind, .addParentHeights)
        // Everything done → informational next measurement.
        let all = profile([(T.date(2026, 9, 20), 157)], parents: true, log: done.habitLog)
        let action = NextActionEngine.next(profile: all, analysis: analyzer.analyze(all), now: T.today, calendar: T.calendar)
        XCTAssertEqual(action.kind, .measureLater)
        XCTAssertFalse(action.isActionable)
    }

    func testMeasurementOutcomes() {
        let one = profile([(T.date(2026, 3, 1), 152)])
        let two = profile([(T.date(2026, 3, 1), 152), (T.date(2026, 9, 1), 156)])
        let unlocked = MeasurementOutcome.compare(before: analyzer.analyze(one), after: analyzer.analyze(two))
        XCTAssertEqual(unlocked.headline, "Growth speed is now available")
        XCTAssertNotNil(unlocked.percentileText)
        let shortTwo = profile([(T.date(2026, 8, 1), 152), (T.date(2026, 9, 1), 153)])
        XCTAssertEqual(MeasurementOutcome.compare(before: analyzer.analyze(profile([(T.date(2026, 8, 1), 152)])), after: analyzer.analyze(shortTwo)).headline, "Your trend has started")
        let sameDay = profile([(T.date(2026, 3, 1), 152), (T.date(2026, 3, 1), 152.4)])
        XCTAssertTrue(MeasurementOutcome.compare(before: analyzer.analyze(one), after: analyzer.analyze(sameDay)).detail.contains("same day"))
        for o in [unlocked] { XCTAssertFalse(o.headline.lowercased().contains("taller")) }
    }

    func testProfileCardSummary() {
        let p = profile([(T.date(2025, 9, 1), 150), (T.date(2026, 9, 1), 157)])
        let s = ProfileCardSummary(profile: p, now: T.today, calendar: T.calendar)
        XCTAssertEqual(s.name, "Me")
        XCTAssertEqual(s.ageText, "14 years")
        XCTAssertEqual(s.heightText, "157.0 cm")
        XCTAssertEqual(s.statusText, "Growing")
    }

    func testProfileSwitchingChangesActiveDashboard() {
        let a = profile([(T.date(2026, 9, 1), 157)])
        var b = profile(birth: T.date(2018, 1, 1), [(T.date(2026, 9, 1), 128)])
        b.subject = .child
        b.nickname = "Leo"
        MainActor.assumeIsolated {
            let (repository, _) = T.repository()
            repository.completeOnboarding(with: a)
            repository.completeOnboarding(with: b)
            XCTAssertEqual(DashboardBuilder(now: T.today, calendar: T.calendar, locale: T.locale).build(for: repository.activeProfile!).title, "Leo’s growth")
            repository.setActiveProfile(a.id)
            XCTAssertEqual(DashboardBuilder(now: T.today, calendar: T.calendar, locale: T.locale).build(for: repository.activeProfile!).title, "Your growth")
            repository.setActiveProfile(UUID())
            XCTAssertEqual(repository.activeProfile?.id, a.id, "Unknown IDs are ignored")
        }
    }

    func testExportContainsEverythingAndIsReadable() throws {
        let p = profile([(T.date(2026, 9, 1), 157)])
        let data = try DataExporter.exportJSON(AppSnapshot(profiles: [p], activeProfileID: p.id))
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("\"heightCm\" : 157"))
        XCTAssertTrue(json.contains("2026-09-01"))
        XCTAssertEqual(DataExporter.fileName(now: T.today, calendar: T.calendar), "growth-data-2026-10-07.json")
    }
}
