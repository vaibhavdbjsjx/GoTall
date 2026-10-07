#if os(iOS)
import SwiftUI
import GrowthCore
import DesignSystem

/// Entry point for the app UI. Decides between data recovery, onboarding and the main app.
public struct AppRootView: View {
    @State private var repository: AppRepository
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let initialTab: AppTab

    public init(repository: AppRepository, initialTab: AppTab = .home) {
        _repository = State(initialValue: repository)
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
        .tint(DS.Colors.accent)
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
