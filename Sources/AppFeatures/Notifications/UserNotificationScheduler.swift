#if os(iOS)
import Foundation
import UserNotifications
import GrowthCore

/// `NotificationScheduling` backed by `UNUserNotificationCenter`. One-off calendar triggers only;
/// identifiers come from `NotificationPlanner`, so re-adding replaces instead of duplicating.
public final class UserNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func authorization() async -> NotificationAuthorization {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .authorized
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    public func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    public func pending() async -> [ScheduledNotification] {
        await center.pendingNotificationRequests().map { request in
            ScheduledNotification(id: request.identifier,
                                  fireDate: (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate(),
                                  title: request.content.title, body: request.content.body)
        }
    }

    public func schedule(_ notification: PlannedNotification) async throws {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        content.threadIdentifier = notification.category.rawValue
        content.categoryIdentifier = notification.category.rawValue
        content.userInfo = ["route": notification.route.encoded]
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notification.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try await center.add(UNNotificationRequest(identifier: notification.id, content: content, trigger: trigger))
    }

    public func remove(ids: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}

#if DEBUG
/// Screenshot harness: behaves as if permission was granted, without touching the system.
public actor PreviewNotificationScheduler: NotificationScheduling {
    var requests: [String: PlannedNotification] = [:]
    public init() {}
    public func authorization() async -> NotificationAuthorization { .authorized }
    public func requestAuthorization() async -> Bool { true }
    public func pending() async -> [ScheduledNotification] {
        requests.values.map { ScheduledNotification(id: $0.id, fireDate: $0.fireDate, title: $0.title, body: $0.body) }
    }
    public func schedule(_ notification: PlannedNotification) async throws { requests[notification.id] = notification }
    public func remove(ids: [String]) async { ids.forEach { requests[$0] = nil } }
}
#endif

/// Routes notification taps into the app and shows reminders as banners if the app is open.
public final class NotificationTapRouter: NSObject, UNUserNotificationCenterDelegate {
    private weak var navigator: AppNavigator?

    @MainActor
    public init(navigator: AppNavigator) {
        self.navigator = navigator
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let encoded = response.notification.request.content.userInfo["route"] as? String,
              let route = NotificationRoute(encoded: encoded) else { return }
        await MainActor.run { navigator?.open(route) }
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}
#endif
