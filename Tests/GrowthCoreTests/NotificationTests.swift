import XCTest
@testable import GrowthCore

/// In-memory stand-in for UNUserNotificationCenter.
actor FakeNotificationScheduler: NotificationScheduling {
    var auth: NotificationAuthorization
    var grantOnRequest: Bool
    var requests: [String: PlannedNotification] = [:]
    var foreign: [ScheduledNotification] = []
    var addCount = 0
    var removeCount = 0
    var permissionRequests = 0

    init(auth: NotificationAuthorization = .notDetermined, grantOnRequest: Bool = true) {
        self.auth = auth
        self.grantOnRequest = grantOnRequest
    }

    func authorization() async -> NotificationAuthorization { auth }
    func requestAuthorization() async -> Bool {
        permissionRequests += 1
        auth = grantOnRequest ? .authorized : .denied
        return grantOnRequest
    }
    func pending() async -> [ScheduledNotification] {
        foreign + requests.values.map { ScheduledNotification(id: $0.id, fireDate: $0.fireDate, title: $0.title, body: $0.body) }
    }
    func schedule(_ notification: PlannedNotification) async throws {
        addCount += 1
        requests[notification.id] = notification // same identifier replaces, as in UNUserNotificationCenter
    }
    func remove(ids: [String]) async {
        removeCount += ids.count
        ids.forEach { requests[$0] = nil }
        foreign.removeAll { ids.contains($0.id) }
    }
    func setForeign(_ items: [ScheduledNotification]) { foreign = items }
}

enum NotificationFixtures {
    static func child(measured: Date, id: UUID = UUID(), log: [HabitDay] = [], name: String = "Ava") -> GrowthProfile {
        GrowthProfile(id: id, subject: .child, nickname: name, birthDate: T.date(2016, 1, 1), chartSex: .female, unitPreference: .centimeters,
                      measurements: [HeightMeasurement(date: measured, heightCm: 135, method: .home, origin: .manual)],
                      habitLog: log, createdAt: T.today, updatedAt: T.today)
    }

    static func days(_ offsets: [Int]) -> [HabitDay] {
        offsets.map { HabitDay(date: T.calendar.startOfDay(for: T.calendar.date(byAdding: .day, value: -$0, to: T.today)!), completed: [.sleep]) }
    }
}

final class NotificationPlannerTests: XCTestCase {
    let planner = NotificationPlanner(now: T.today, calendar: T.calendar) // 2026-10-07 10:00 UTC

    func testNothingWhenAllOff() {
        XCTAssertEqual(planner.plan(preferences: NotificationPreferences(), profiles: [NotificationFixtures.child(measured: T.today)]), [])
        XCTAssertFalse(NotificationPreferences().anyEnabled, "conservative defaults: everything off")
    }

    func testMeasurementReminderRecommendedInterval() {
        let plan = planner.plan(preferences: NotificationPreferences(measurementReminders: true), profiles: [NotificationFixtures.child(measured: T.date(2026, 9, 1))])
        XCTAssertEqual(plan.count, 1)
        XCTAssertEqual(plan[0].category, .measurementReminder)
        XCTAssertEqual(plan[0].fireDate, T.calendar.date(from: DateComponents(year: 2026, month: 12, day: 1, hour: 10))!)
        XCTAssertTrue(plan[0].body.contains("Ava"))
    }

    func testMeasurementReminderCustomIntervalAndDue() {
        let custom = planner.plan(preferences: NotificationPreferences(measurementReminders: true, measurementInterval: .months(6)),
                                  profiles: [NotificationFixtures.child(measured: T.date(2026, 9, 1))])
        XCTAssertEqual(custom[0].fireDate, T.calendar.date(from: DateComponents(year: 2027, month: 3, day: 1, hour: 10))!)
        let due = planner.plan(preferences: NotificationPreferences(measurementReminders: true), profiles: [NotificationFixtures.child(measured: T.date(2026, 1, 1))])
        XCTAssertEqual(due[0].fireDate, T.calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 10))!, "already due: tomorrow morning")
    }

    func testAdultsGetNoRecommendedReminderButCanChooseOne() {
        let adult = GrowthProfile(subject: .myself, birthDate: T.date(1990, 1, 1), chartSex: .male, unitPreference: .centimeters,
                                  measurements: [HeightMeasurement(date: T.date(2026, 9, 1), heightCm: 178, method: .home, origin: .manual)], createdAt: T.today, updatedAt: T.today)
        XCTAssertEqual(planner.plan(preferences: NotificationPreferences(measurementReminders: true), profiles: [adult]), [])
        XCTAssertEqual(planner.plan(preferences: NotificationPreferences(measurementReminders: true, measurementInterval: .months(12)), profiles: [adult]).count, 1)
    }

    func testHeightIsNeverRequestedDaily() {
        let plan = planner.plan(preferences: NotificationPreferences(measurementReminders: true, measurementInterval: .months(1)),
                                profiles: [NotificationFixtures.child(measured: T.date(2026, 10, 6))])
        XCTAssertEqual(plan.filter { $0.category == .measurementReminder }.count, 1)
        XCTAssertGreaterThanOrEqual(plan[0].fireDate.timeIntervalSince(T.date(2026, 10, 6)), 28 * 86_400)
    }

    func testDailyCheckInWindow() {
        let prefs = NotificationPreferences(dailyCheckIn: true, dailyCheckInTime: TimeOfDay(hour: 19, minute: 0))
        let plan = planner.plan(preferences: prefs, profiles: [NotificationFixtures.child(measured: T.today)])
        XCTAssertEqual(plan.count, 7)
        XCTAssertEqual(plan.first?.fireDate, T.calendar.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 19))!)
        XCTAssertEqual(Set(plan.map(\.id)).count, 7, "unique identifiers")
        XCTAssertTrue(plan.allSatisfy { $0.fireDate > T.today && $0.route == .habits })

        let early = planner.plan(preferences: NotificationPreferences(dailyCheckIn: true, dailyCheckInTime: TimeOfDay(hour: 8, minute: 0)), profiles: [])
        XCTAssertEqual(early.first?.fireDate, T.calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 8))!, "08:00 already passed today")
        XCTAssertEqual(early.count, 6)
    }

    func testDailySkipsTodayAfterACheckIn() {
        let prefs = NotificationPreferences(dailyCheckIn: true)
        let checkedIn = NotificationFixtures.child(measured: T.today, log: NotificationFixtures.days([0]))
        let plan = planner.plan(preferences: prefs, profiles: [checkedIn])
        XCTAssertEqual(plan.count, 6)
        XCTAssertFalse(plan.contains { T.calendar.isDate($0.fireDate, inSameDayAs: T.today) })
    }

    func testWeeklySummaryOnlyWithMeaningfulActivity() {
        let prefs = NotificationPreferences(weeklySummary: true)
        let quiet = NotificationFixtures.child(measured: T.date(2026, 8, 1), log: NotificationFixtures.days([1]))
        XCTAssertEqual(planner.plan(preferences: prefs, profiles: [quiet]), [])
        let active = NotificationFixtures.child(measured: T.date(2026, 8, 1), log: NotificationFixtures.days([0, 1, 3]))
        let plan = planner.plan(preferences: prefs, profiles: [active])
        XCTAssertEqual(plan.count, 1)
        XCTAssertEqual(T.calendar.component(.weekday, from: plan[0].fireDate), 1)
        XCTAssertEqual(T.calendar.component(.hour, from: plan[0].fireDate), 18)
        XCTAssertEqual(plan[0].body, "Your week in review is ready.")
        let measured = NotificationFixtures.child(measured: T.date(2026, 10, 5))
        XCTAssertEqual(planner.plan(preferences: prefs, profiles: [measured]).count, 1, "a measurement this week is meaningful")
    }

    func testCopyIsCalm() {
        let prefs = NotificationPreferences(measurementReminders: true, dailyCheckIn: true, weeklySummary: true)
        let profile = NotificationFixtures.child(measured: T.date(2026, 9, 1), log: NotificationFixtures.days([1, 2, 3]))
        let plan = planner.plan(preferences: prefs, profiles: [profile])
        XCTAssertEqual(Set(plan.map(\.category)).count, 3)
        for n in plan {
            let text = (n.title + " " + n.body).lowercased()
            XCTAssertEqual(CopyGuard.violations(in: text), [])
            for word in ["losing", "lose", "streak", "don't miss", "hurry", "last chance", "taller", "gain", "grow more"] {
                XCTAssertFalse(text.contains(word), text)
            }
        }
    }

    func testRoutesRoundTrip() {
        let id = UUID()
        for route in [NotificationRoute.addMeasurement(profileID: id), .habits, .weeklySummary] {
            XCTAssertEqual(NotificationRoute(encoded: route.encoded), route)
        }
        XCTAssertNil(NotificationRoute(encoded: "nonsense"))
    }

    func testPreferencesPersistAndOldFilesDecode() throws {
        let store = try T.makeFileStore()
        MainActor.assumeIsolated {
            let repository = AppRepository(store: store)
            repository.setNotificationPreferences(NotificationPreferences(measurementInterval: .months(4), dailyCheckIn: true))
        }
        guard case .loaded(let loaded) = store.load() else { return XCTFail() }
        XCTAssertTrue(loaded.notificationPreferences.dailyCheckIn)
        XCTAssertEqual(loaded.notificationPreferences.measurementInterval, .months(4))
        let old = try FileProfileStore.makeDecoder().decode(AppSnapshot.self, from: Data("{\"profiles\":[]}".utf8))
        XCTAssertEqual(old.notificationPreferences, NotificationPreferences())
        // Phase 4 files saved preferences without an interval.
        let phase4 = try FileProfileStore.makeDecoder().decode(NotificationPreferences.self,
            from: Data("{\"measurementReminders\":true,\"dailyCheckIn\":false,\"dailyCheckInTime\":{\"hour\":8,\"minute\":30},\"weeklySummary\":true}".utf8))
        XCTAssertEqual(phase4.measurementInterval, .recommended)
        XCTAssertEqual(phase4.dailyCheckInTime, TimeOfDay(hour: 8, minute: 30))
        XCTAssertEqual(CheckInTimePreset.preset(for: TimeOfDay(hour: 8, minute: 0)), .morning)
        XCTAssertEqual(CheckInTimePreset.preset(for: TimeOfDay(hour: 8, minute: 30)), .custom)
    }
}

final class NotificationReconcilerTests: XCTestCase {
    func planned(_ id: String, _ date: Date, body: String = "b") -> PlannedNotification {
        PlannedNotification(id: "growth." + id, category: .dailyCheckIn, fireDate: date, title: "t", body: body, route: .habits)
    }
    func pending(_ p: PlannedNotification) -> ScheduledNotification { ScheduledNotification(id: p.id, fireDate: p.fireDate, title: p.title, body: p.body) }

    func testUnchangedKeptChangedReplacedStaleRemovedForeignUntouched() {
        let keep = planned("a", T.today)
        let moved = planned("b", T.today)
        let stale = planned("c", T.today)
        let foreign = ScheduledNotification(id: "other.app.thing", fireDate: T.today, title: "x", body: "y")
        let movedNow = planned("b", T.today.addingTimeInterval(86_400))
        let new = planned("d", T.today)
        let plan = NotificationReconciler.reconcile(pending: [pending(keep), pending(moved), pending(stale), foreign],
                                                    desired: [keep, movedNow, new], calendar: T.calendar)
        XCTAssertEqual(Set(plan.toRemove), ["growth.b", "growth.c"])
        XCTAssertEqual(plan.toAdd.map(\.id), ["growth.b", "growth.d"])
    }

    func testDuplicatesAreCollapsed() {
        let a = planned("a", T.today)
        let plan = NotificationReconciler.reconcile(pending: [pending(a), pending(a)], desired: [a], calendar: T.calendar)
        XCTAssertEqual(plan.toRemove, ["growth.a"])
        XCTAssertEqual(plan.toAdd.map(\.id), ["growth.a"])
    }
}

final class NotificationCoordinatorTests: XCTestCase {
    @MainActor
    func make(_ scheduler: FakeNotificationScheduler, profiles: [GrowthProfile]) -> (NotificationCoordinator, AppRepository) {
        var snapshot = AppSnapshot.empty
        snapshot.profiles = profiles
        snapshot.activeProfileID = profiles.first?.id
        let (repository, _) = T.repository(snapshot)
        let coordinator = NotificationCoordinator(scheduler: scheduler, calendar: T.calendar, now: { T.today })
        return (coordinator, repository)
    }

    @MainActor
    func testEnablingAsksPermissionOnceAndSchedules() async {
        let scheduler = FakeNotificationScheduler()
        let (coordinator, repository) = make(scheduler, profiles: [NotificationFixtures.child(measured: T.date(2026, 9, 1))])
        await coordinator.sync(repository.snapshot)
        let before = await scheduler.permissionRequests
        XCTAssertEqual(before, 0, "never asked at launch")
        let result = await coordinator.setCategory(.measurementReminder, enabled: true, repository: repository)
        XCTAssertEqual(result, .updated)
        XCTAssertTrue(repository.snapshot.notificationPreferences.measurementReminders)
        XCTAssertEqual(coordinator.scheduled.count, 1)
        XCTAssertNotNil(coordinator.nextMeasurementReminder(for: repository.profiles[0].id))
        _ = await coordinator.setCategory(.dailyCheckIn, enabled: true, repository: repository)
        let asks = await scheduler.permissionRequests
        XCTAssertEqual(asks, 1)
        XCTAssertEqual(coordinator.scheduled.count, 8)
        XCTAssertEqual(coordinator.nextScheduled(.dailyCheckIn)?.title, "Daily check-in")
    }

    @MainActor
    func testDeniedPermissionLeavesPreferenceOff() async {
        let scheduler = FakeNotificationScheduler(grantOnRequest: false)
        let (coordinator, repository) = make(scheduler, profiles: [NotificationFixtures.child(measured: T.date(2026, 9, 1))])
        let result = await coordinator.setCategory(.weeklySummary, enabled: true, repository: repository)
        XCTAssertEqual(result, .needsSystemSettings)
        XCTAssertFalse(repository.snapshot.notificationPreferences.weeklySummary)
        let again = await coordinator.setCategory(.weeklySummary, enabled: true, repository: repository)
        XCTAssertEqual(again, .needsSystemSettings)
        let asks = await scheduler.permissionRequests
        XCTAssertEqual(asks, 1, "iOS only shows the prompt once; afterwards we point to Settings")
    }

    @MainActor
    func testDisablingCancels() async {
        let scheduler = FakeNotificationScheduler(auth: .authorized)
        let (coordinator, repository) = make(scheduler, profiles: [NotificationFixtures.child(measured: T.date(2026, 9, 1))])
        _ = await coordinator.setCategory(.dailyCheckIn, enabled: true, repository: repository)
        XCTAssertEqual(coordinator.scheduled.count, 7)
        _ = await coordinator.setCategory(.dailyCheckIn, enabled: false, repository: repository)
        XCTAssertEqual(coordinator.scheduled.count, 0)
        let held = await scheduler.requests
        XCTAssertTrue(held.isEmpty)
    }

    @MainActor
    func testRepeatedSyncNeverDuplicates() async {
        let scheduler = FakeNotificationScheduler(auth: .authorized)
        let (coordinator, repository) = make(scheduler, profiles: [NotificationFixtures.child(measured: T.date(2026, 9, 1))])
        repository.setNotificationPreferences(NotificationPreferences(measurementReminders: true, dailyCheckIn: true))
        await coordinator.sync(repository.snapshot)
        let adds = await scheduler.addCount
        async let a: Void = coordinator.sync(repository.snapshot)
        async let b: Void = coordinator.sync(repository.snapshot)
        _ = await (a, b)
        await coordinator.sync(repository.snapshot)
        let addsAfter = await scheduler.addCount
        XCTAssertEqual(addsAfter, adds, "unchanged reminders are not re-added")
        let pending = await scheduler.pending()
        XCTAssertEqual(pending.count, Set(pending.map(\.id)).count)
        XCTAssertEqual(pending.count, 8)
    }

    @MainActor
    func testMeasurementChangeReschedules() async throws {
        let scheduler = FakeNotificationScheduler(auth: .authorized)
        let profile = NotificationFixtures.child(measured: T.date(2026, 9, 1))
        let (coordinator, repository) = make(scheduler, profiles: [profile])
        repository.setNotificationPreferences(NotificationPreferences(measurementReminders: true))
        await coordinator.sync(repository.snapshot)
        XCTAssertEqual(coordinator.nextMeasurementReminder(for: profile.id), T.calendar.date(from: DateComponents(year: 2026, month: 12, day: 1, hour: 10)))
        repository.addMeasurement(HeightMeasurement(date: T.date(2026, 10, 6), heightCm: 136, method: .home, origin: .manual), to: profile.id, at: T.today)
        await coordinator.sync(repository.snapshot)
        XCTAssertEqual(coordinator.nextMeasurementReminder(for: profile.id), T.calendar.date(from: DateComponents(year: 2027, month: 1, day: 6, hour: 10)))
        XCTAssertEqual(coordinator.scheduled.count, 1)
    }

    @MainActor
    func testPreferenceAndProfileChanges() async {
        let scheduler = FakeNotificationScheduler(auth: .authorized)
        let a = NotificationFixtures.child(measured: T.date(2026, 9, 1))
        let b = NotificationFixtures.child(measured: T.date(2026, 8, 1), name: "Leo")
        let (coordinator, repository) = make(scheduler, profiles: [a, b])
        repository.setNotificationPreferences(NotificationPreferences(measurementReminders: true, dailyCheckIn: true))
        await coordinator.sync(repository.snapshot)
        XCTAssertEqual(coordinator.scheduled.filter { $0.id.contains("measure") }.count, 2)

        var prefs = repository.snapshot.notificationPreferences
        prefs.dailyCheckInTime = TimeOfDay(hour: 20, minute: 15)
        repository.setNotificationPreferences(prefs)
        await coordinator.sync(repository.snapshot)
        XCTAssertEqual(coordinator.nextScheduled(.dailyCheckIn).flatMap(\.fireDate).map { T.calendar.component(.minute, from: $0) }, 15)

        repository.deleteProfile(b.id)
        await coordinator.sync(repository.snapshot)
        XCTAssertNil(coordinator.nextMeasurementReminder(for: b.id), "deleted profile's reminder removed")
        XCTAssertNotNil(coordinator.nextMeasurementReminder(for: a.id))
    }

    @MainActor
    func testForeignNotificationsUntouchedAndRevokedPermissionClearsOurs() async {
        let scheduler = FakeNotificationScheduler(auth: .authorized)
        await scheduler.setForeign([ScheduledNotification(id: "other.reminder", fireDate: T.today, title: "x", body: "y")])
        let (coordinator, repository) = make(scheduler, profiles: [NotificationFixtures.child(measured: T.date(2026, 9, 1))])
        repository.setNotificationPreferences(NotificationPreferences(measurementReminders: true))
        await coordinator.sync(repository.snapshot)
        let pending = await scheduler.pending()
        XCTAssertTrue(pending.contains { $0.id == "other.reminder" })
        XCTAssertEqual(coordinator.scheduled.count, 1, "only this app's reminders are reported")
    }
}
