#if os(iOS)
import SwiftUI
import GrowthCore
import DesignSystem

/// Entry point for the app UI. Decides between data recovery, onboarding and the main app.
public struct AppRootView: View {
    @State private var repository: AppRepository
    @State private var entitlements: EntitlementStore
    @State private var notifications: NotificationCoordinator
    @State private var navigator: AppNavigator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue

    private let initialTab: AppTab

    public init(repository: AppRepository, entitlements: EntitlementStore, notifications: NotificationCoordinator,
                navigator: AppNavigator, initialTab: AppTab = .home) {
        _repository = State(initialValue: repository)
        _entitlements = State(initialValue: entitlements)
        _notifications = State(initialValue: notifications)
        _navigator = State(initialValue: navigator)
        self.initialTab = initialTab
    }

    public var body: some View {
        Group {
            switch repository.state {
            case .unreadableData:
                UnreadableDataView(repository: repository)
            case .ready:
                if repository.profiles.isEmpty {
                    OnboardingHost(repository: repository, mode: .firstRun)
                        .transition(.opacity)
                } else {
                    MainTabView(repository: repository, initialTab: initialTab)
                        .transition(.opacity)
                }
            }
        }
        .animation(Motion.resolved(Motion.reveal, reduceMotion: reduceMotion), value: repository.profiles.isEmpty)
        // The sheet is attached before the environment so its content receives the same services.
        .paywallSheet(Bindable(navigator).paywall)
        .environment(entitlements)
        .environment(notifications)
        .environment(navigator)
        // Entitlements are recomputed from verified transactions at launch and whenever the app returns to the
        // foreground (e.g. after changing the subscription in Settings). Reminders are re-planned from the data.
        .task {
            await entitlements.start()
            await notifications.sync(repository.snapshot)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await entitlements.refresh()
                await notifications.sync(repository.snapshot)
            }
        }
        .onChange(of: repository.snapshot) { _, snapshot in
            Task { await notifications.sync(snapshot) }
        }
        .tint(DS.Colors.accent)
        .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
    }
}

/// Shown if saved data exists but can't be read. Nothing is deleted without an explicit choice.
struct UnreadableDataView: View {
    let repository: AppRepository
    @State private var failed = false

    var body: some View {
        ErrorStateView(
            title: "We couldn't open your saved data",
            message: failed
                ? "Something went wrong again. Please try restarting the app."
                : "Your data is still on this device. Starting fresh keeps a copy of the old file so it can be recovered later.",
            primaryTitle: "Start fresh",
            primaryAction: {
                do { try repository.startFreshAfterUnreadableData() } catch { failed = true }
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dsPageBackground()
    }
}
#endif
