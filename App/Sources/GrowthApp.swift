import SwiftUI
import UserNotifications
import GrowthCore
import AppFeatures

@main
struct GrowthApp: App {
    @State private var repository: AppRepository
    @State private var navigator: AppNavigator
    @State private var entitlements: EntitlementStore
    @State private var notifications: NotificationCoordinator
    private let tapRouter: NotificationTapRouter

    init() {
        let navigator = AppNavigator()
        let router = NotificationTapRouter(navigator: navigator)
        // Set before launch finishes so a tap that opened the app is routed.
        UNUserNotificationCenter.current().delegate = router
        tapRouter = router
        _navigator = State(initialValue: navigator)
        _repository = State(initialValue: Self.makeRepository())
        _entitlements = State(initialValue: Self.makeEntitlements())
        _notifications = State(initialValue: Self.makeNotifications())
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(repository: repository, entitlements: entitlements, notifications: notifications,
                        navigator: navigator, initialTab: Self.initialTab)
        }
    }

    /// Local-first storage. If the Application Support directory can't be created (very rare),
    /// fall back to in-memory storage so the app still opens; the save-error banner explains the situation.
    @MainActor
    private static func makeRepository() -> AppRepository {
        #if DEBUG
        // Screenshot/UI-test harness: `-demoScenario teen|parent|starter|adult|concern|onboarding` uses synthetic data in memory.
        if let name = UserDefaults.standard.string(forKey: "demoScenario"), let scenario = DemoScenario(rawValue: name) {
            var snapshot = scenario.snapshot()
            if UserDefaults.standard.bool(forKey: "demoNotifications") {
                snapshot.notificationPreferences = NotificationPreferences(measurementReminders: true, dailyCheckIn: true, weeklySummary: true)
            }
            return AppRepository(store: InMemoryProfileStore(snapshot: snapshot))
        }
        #endif
        if let store = try? FileProfileStore.defaultStore() {
            return AppRepository(store: store)
        }
        return AppRepository(store: InMemoryProfileStore())
    }

    /// StoreKit 2 in every build; DEBUG builds can swap in a preview store with `-storeMode <mode>`.
    @MainActor
    private static func makeEntitlements() -> EntitlementStore {
        #if DEBUG
        if let mode = UserDefaults.standard.string(forKey: "storeMode").flatMap(PreviewSubscriptionService.Mode.init(rawValue:)) {
            return EntitlementStore(service: PreviewSubscriptionService(mode: mode))
        }
        #endif
        return EntitlementStore(service: StoreKitSubscriptionService())
    }

    @MainActor
    private static func makeNotifications() -> NotificationCoordinator {
        #if DEBUG
        if UserDefaults.standard.string(forKey: "notificationsMode") == "preview" {
            return NotificationCoordinator(scheduler: PreviewNotificationScheduler())
        }
        #endif
        return NotificationCoordinator(scheduler: UserNotificationScheduler())
    }

    private static var initialTab: AppTab {
        #if DEBUG
        if let name = UserDefaults.standard.string(forKey: "initialTab"), let tab = AppTab(rawValue: name) { return tab }
        #endif
        return .home
    }
}
