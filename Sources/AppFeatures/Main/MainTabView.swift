#if os(iOS)
import SwiftUI
import GrowthCore
import DesignSystem

/// Four destinations. Future features slot in without new tabs:
/// coach → a Home entry + sheet; reports → Growth; nutrition/exercise → Habits; subscription & widgets → Profile.
enum AppTab: Hashable {
    case home, growth, habits, profile
}

struct MainTabView: View {
    let repository: AppRepository
    @State private var selection: AppTab = .home
    @State private var showsAddMeasurement = false

    var body: some View {
        TabView(selection: $selection) {
            HomeView(repository: repository, onAction: handle)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)
            GrowthView(repository: repository)
                .tabItem { Label("Growth", systemImage: "chart.xyaxis.line") }
                .tag(AppTab.growth)
            HabitsView(repository: repository)
                .tabItem { Label("Habits", systemImage: "checklist") }
                .tag(AppTab.habits)
            ProfileView(repository: repository)
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
        .sheet(isPresented: $showsAddMeasurement) {
            if let profile = repository.activeProfile {
                AddMeasurementSheet(repository: repository, profile: profile)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let error = repository.lastSaveError {
                InfoBanner("Changes couldn't be saved. They'll be retried automatically. (\(error.prefix(60)))", tone: .caution)
                    .padding(.horizontal, DS.Spacing.page)
            }
        }
    }

    private func handle(_ action: DashboardState.QuickAction) {
        switch action {
        case .measure: showsAddMeasurement = true
        case .viewGrowth: selection = .growth
        case .habits: selection = .habits
        }
    }
}

/// Menu for switching between profiles (parents with several children).
struct ProfileSwitcher: View {
    let repository: AppRepository

    var body: some View {
        if repository.profiles.count > 1, let active = repository.activeProfile {
            Menu {
                ForEach(repository.profiles) { profile in
                    Button {
                        repository.setActiveProfile(profile.id)
                    } label: {
                        if profile.id == active.id {
                            Label(profile.displayLabel, systemImage: "checkmark")
                        } else {
                            Text(profile.displayLabel)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(active.displayLabel).font(DS.Typography.subheadline.weight(.semibold))
                    Image(systemName: "chevron.down").font(.caption.weight(.bold))
                }
                .padding(.horizontal, DS.Spacing.sm)
                .frame(minHeight: DS.minimumTapTarget)
                .background(DS.Colors.surfaceSecondary, in: Capsule())
                .foregroundStyle(DS.Colors.textPrimary)
            }
            .accessibilityLabel("Switch profile, current: \(active.displayLabel)")
        }
    }
}

extension GrowthProfile {
    var displayLabel: String {
        if subject == .myself { return "Me" }
        return nickname ?? "Child"
    }
}
#endif
