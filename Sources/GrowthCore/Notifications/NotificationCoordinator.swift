import Foundation
import Observation

/// Keeps the system's pending notifications in line with the saved preferences and data.
/// Views only call `setCategory`/`sync`; scheduling logic lives in `NotificationPlanner` and `NotificationReconciler`.
///
/// Permission is never requested at launch: only when the person turns a reminder on.
@MainActor
@Observable
public final class NotificationCoordinator {
    public enum ToggleResult: Sendable, Equatable {
        case updated
        /// iOS permission was declined earlier; the preference stays off and the person is pointed to Settings.
        case needsSystemSettings
    }

    public private(set) var authorization: NotificationAuthorization = .notDetermined
    /// This app's pending reminders as the system reports them after the last sync.
    public private(set) var scheduled: [ScheduledNotification] = []
    public private(set) var lastSyncError: String?

    @ObservationIgnored private let scheduler: NotificationScheduling
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var syncInFlight = false
    @ObservationIgnored private var queuedSnapshot: AppSnapshot?

    public init(scheduler: NotificationScheduling, calendar: Calendar = .current, now: @escaping @Sendable () -> Date = { Date() }) {
        self.scheduler = scheduler
        self.calendar = calendar
        self.now = now
    }

    public func refreshAuthorization() async {
        authorization = await scheduler.authorization()
    }

    /// Turns a category on or off. Turning one on asks for permission the first time.
    public func setCategory(_ category: NotificationCategory, enabled: Bool, repository: AppRepository) async -> ToggleResult {
        if enabled {
            await refreshAuthorization()
            switch authorization {
            case .denied:
                return .needsSystemSettings
            case .notDetermined:
                let granted = await scheduler.requestAuthorization()
                await refreshAuthorization()
                if !granted { return .needsSystemSettings }
            case .authorized:
                break
            }
        }
        var prefs = repository.snapshot.notificationPreferences
        prefs.set(category, enabled: enabled)
        repository.setNotificationPreferences(prefs)
        await sync(repository.snapshot)
        return .updated
    }

    /// Re-plans and reconciles. Calls made while a sync is running are coalesced into one follow-up pass,
    /// so overlapping triggers can't schedule anything twice.
    public func sync(_ snapshot: AppSnapshot) async {
        queuedSnapshot = snapshot
        guard !syncInFlight else { return }
        syncInFlight = true
        defer { syncInFlight = false }
        while let next = queuedSnapshot {
            queuedSnapshot = nil
            await perform(next)
        }
    }

    private func perform(_ snapshot: AppSnapshot) async {
        authorization = await scheduler.authorization()
        let desired = authorization == .authorized
            ? NotificationPlanner(now: now(), calendar: calendar).plan(preferences: snapshot.notificationPreferences, profiles: snapshot.profiles)
            : []
        let pending = await scheduler.pending()
        let plan = NotificationReconciler.reconcile(pending: pending, desired: desired, calendar: calendar)
        if !plan.toRemove.isEmpty { await scheduler.remove(ids: plan.toRemove) }
        lastSyncError = nil
        for notification in plan.toAdd {
            do { try await scheduler.schedule(notification) } catch { lastSyncError = String(describing: error) }
        }
        scheduled = await scheduler.pending()
            .filter { $0.id.hasPrefix(PlannedNotification.idPrefix) }
            .sorted { ($0.fireDate ?? .distantFuture) < ($1.fireDate ?? .distantFuture) }
    }

    public func nextScheduled(_ category: NotificationCategory) -> ScheduledNotification? {
        let prefix = PlannedNotification.idPrefix + Self.idSegment(category)
        return scheduled.first { $0.id.hasPrefix(prefix) }
    }

    public func nextMeasurementReminder(for profileID: UUID) -> Date? {
        scheduled.first { $0.id == PlannedNotification.idPrefix + "measure." + profileID.uuidString }?.fireDate
    }

    static func idSegment(_ category: NotificationCategory) -> String {
        switch category {
        case .measurementReminder: return "measure."
        case .dailyCheckIn: return "checkin."
        case .weeklySummary: return "weekly."
        }
    }
}
