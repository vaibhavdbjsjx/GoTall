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
    @Environment(AppNavigator.self) private var navigator
    @State private var selection: AppTab
    @State private var showsReport = false
    @State private var showsAddMeasurement = false
    @State private var showsSwitcher = false
    @State private var editingFamily: GrowthProfile?
    @State private var explanationRequest = 0

    init(repository: AppRepository, initialTab: AppTab = .home) {
        self.repository = repository
        _selection = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $selection) {
            HomeView(repository: repository, onAction: handle)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)
            GrowthView(repository: repository, explanationRequest: explanationRequest)
                .tabItem { Label("Growth", systemImage: "chart.xyaxis.line") }
                .tag(AppTab.growth)
            HabitsView(repository: repository)
                .tabItem { Label("Habits", systemImage: "checklist") }
                .tag(AppTab.habits)
            ProfileView(repository: repository)
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
        .sensoryFeedback(.selection, trigger: selection)
        .sheet(isPresented: $showsAddMeasurement) {
            if let profile = repository.activeProfile {
                AddMeasurementFlow(repository: repository, profile: profile)
            }
        }
        .sheet(isPresented: $showsSwitcher) {
            ProfileSwitcherSheet(repository: repository)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingFamily) { profile in
            EditProfileView(repository: repository, profile: profile, focus: nil)
        }
        .sheet(isPresented: $showsReport) {
            NavigationStack {
                ReportPreviewView(repository: repository)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showsReport = false } } }
            }
        }
        .sheet(isPresented: Bindable(navigator).showsWeeklySummary) {
            WeeklySummaryView(repository: repository)
        }
        .onChange(of: navigator.route) { _, route in
            guard let route else { return }
            navigator.route = nil
            switch route {
            case .addMeasurement(let profileID):
                repository.setActiveProfile(profileID)
                selection = .home
                showsAddMeasurement = true
            case .habits:
                selection = .habits
            case .weeklySummary:
                navigator.showsWeeklySummary = true
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if repository.lastSaveError != nil {
                InfoBanner("Changes couldn't be saved. They'll be retried automatically.", tone: .caution)
                    .padding(.horizontal, DS.Spacing.page)
            }
        }
        .onAppear(perform: applyLaunchOptions)
    }

    private func handle(_ action: HomeAction) {
        switch action {
        case .measure: showsAddMeasurement = true
        case .growth: selection = .growth
        case .habits: selection = .habits
        case .explanation:
            selection = .growth
            explanationRequest += 1
        case .editFamily: editingFamily = repository.activeProfile
        case .switchProfile: showsSwitcher = true
        case .report: showsReport = true
        }
    }

    private func applyLaunchOptions() {
        #if DEBUG
        // Screenshot harness only.
        if UserDefaults.standard.bool(forKey: "openAddMeasurement") { showsAddMeasurement = true }
        if UserDefaults.standard.bool(forKey: "openProfileSwitcher") { showsSwitcher = true }
        if UserDefaults.standard.bool(forKey: "openWeeklySummary") { navigator.showsWeeklySummary = true }
        if let context = UserDefaults.standard.string(forKey: "openPaywall").flatMap(PaywallContext.init(rawValue:)) { navigator.showPaywall(context) }
        #endif
    }
}

/// Header button that opens the profile switcher. Hidden when there's only one profile.
struct ProfileSwitcherButton: View {
    let repository: AppRepository
    let action: () -> Void

    var body: some View {
        if repository.profiles.count > 1, let active = repository.activeProfile {
            Button(action: action) {
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
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Switch profile, current: \(active.displayLabel)")
        }
    }
}

/// Compact switcher for toolbars (Growth, Habits): same sheet, smaller control.
struct ProfileSwitcher: View {
    let repository: AppRepository
    @State private var showsSheet = false

    var body: some View {
        ProfileSwitcherButton(repository: repository) { showsSheet = true }
            .sheet(isPresented: $showsSheet) {
                ProfileSwitcherSheet(repository: repository)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
    }
}

/// Cards for each profile: avatar, name, age, current height and a data-justified status.
struct ProfileSwitcherSheet: View {
    let repository: AppRepository
    @Environment(\.dismiss) private var dismiss
    @Environment(EntitlementStore.self) private var entitlements
    @State private var showsAddProfile = false
    @State private var paywall: PaywallContext?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.sm) {
                    ForEach(repository.profiles) { profile in
                        let summary = ProfileCardSummary(profile: profile, now: Date(), calendar: .current)
                        let isActive = profile.id == repository.activeProfile?.id
                        Button {
                            withAnimation(Motion.standard) { repository.setActiveProfile(profile.id) }
                            dismiss()
                        } label: {
                            HStack(spacing: DS.Spacing.md) {
                                ProfileAvatar(profile: profile, size: 48)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(summary.name).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                                    Text([summary.ageText, summary.heightText].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                        .font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                                    Text(summary.statusText).font(DS.Typography.caption).foregroundStyle(DS.Colors.accent)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(isActive ? DS.Colors.accent : DS.Colors.separator)
                            }
                            .padding(DS.Spacing.md)
                            .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                                .strokeBorder(isActive ? DS.Colors.accent : DS.Colors.separator, lineWidth: isActive ? 2 : 1))
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
                    }
                    let canAdd = entitlements.canAddProfile(existingCount: repository.profiles.count)
                    AppButton("Add a child", systemImage: "plus", kind: .secondary) {
                        if canAdd {
                            showsAddProfile = true
                        } else {
                            paywall = .family
                        }
                    }
                    .padding(.top, DS.Spacing.xs)
                    .accessibilityIdentifier("switcher.addChild")
                    if !canAdd {
                        HStack(spacing: DS.Spacing.xs) {
                            PremiumBadge()
                            Text("Family profiles are part of Premium. Every profile here stays free to use.")
                                .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(DS.Spacing.page)
            }
            .dsPageBackground()
            .navigationTitle("Profiles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .paywallSheet($paywall)
            .fullScreenCover(isPresented: $showsAddProfile) {
                OnboardingHost(repository: repository, mode: .additionalProfile,
                               onCancel: { showsAddProfile = false },
                               onFinish: { showsAddProfile = false; dismiss() })
            }
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
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: Circle())
            .accessibilityHidden(true)
    }

    private var color: Color {
        let palette: [Color] = [Color(red: 0.04, green: 0.44, blue: 0.37), Color(red: 0.66, green: 0.31, blue: 0.15),
                                Color(red: 0.30, green: 0.36, blue: 0.70), Color(red: 0.50, green: 0.33, blue: 0.58)]
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
