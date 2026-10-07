#if os(iOS)
import SwiftUI
import GrowthCore
import DesignSystem

/// Four destinations. Future features slot in without new tabs:
/// coach → a Home entry + sheet; reports → Growth; nutrition/exercise → Habits; subscription & widgets → Profile.
public enum AppTab: String, Hashable {
    case home, growth, habits, profile
}

struct MainTabView: View {
    let repository: AppRepository
    @State private var selection: AppTab
    @State private var showsAddMeasurement = false

    init(repository: AppRepository, initialTab: AppTab = .home) {
        self.repository = repository
        _selection = State(initialValue: initialTab)
    }

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
                MeasurementEditorSheet(repository: repository, profile: profile, route: .add)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if repository.lastSaveError != nil {
                InfoBanner("Changes couldn't be saved. They'll be retried automatically.", tone: .caution)
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

/// Avatar menu for switching between profiles (parents with several children).
struct ProfileSwitcher: View {
    let repository: AppRepository

    var body: some View {
        if repository.profiles.count > 1, let active = repository.activeProfile {
            Menu {
                Section("Switch profile") {
                    ForEach(repository.profiles) { profile in
                        Button {
                            withAnimation(Motion.standard) { repository.setActiveProfile(profile.id) }
                        } label: {
                            if profile.id == active.id {
                                Label(profile.displayLabel, systemImage: "checkmark")
                            } else {
                                Text(profile.displayLabel)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    ProfileAvatar(profile: active, size: 30)
                    Text(active.displayLabel).font(DS.Typography.subheadline.weight(.semibold))
                    Image(systemName: "chevron.down").font(.caption.weight(.bold))
                }
                .padding(.leading, 4)
                .padding(.trailing, DS.Spacing.sm)
                .frame(minHeight: DS.minimumTapTarget)
                .background(DS.Colors.surfaceSecondary, in: Capsule())
                .foregroundStyle(DS.Colors.textPrimary)
            }
            .accessibilityLabel("Switch profile, current: \(active.displayLabel)")
        }
    }
}

/// Initial-letter avatar with a stable colour per profile.
struct ProfileAvatar: View {
    let profile: GrowthProfile
    let size: CGFloat

    var body: some View {
        let initial = profile.subject == .myself ? "Me" : String(profile.displayLabel.prefix(1)).uppercased()
        Text(initial)
            .font(.system(size: size * (initial.count > 1 ? 0.36 : 0.45), weight: .bold, design: .rounded))
            .foregroundStyle(DS.Colors.onAccent)
            .frame(width: size, height: size)
            .background(color, in: Circle())
            .accessibilityHidden(true)
    }

    private var color: Color {
        let palette: [Color] = [DS.Colors.accent, DS.Colors.warm, Color(red: 0.36, green: 0.42, blue: 0.75), Color(red: 0.55, green: 0.38, blue: 0.62)]
        // Stable across launches (hashValue is randomised per process).
        let index = profile.id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) } % palette.count
        return palette[index]
    }
}

extension GrowthProfile {
    var displayLabel: String {
        if subject == .myself { return "Me" }
        return nickname ?? "Child"
    }
}
#endif
