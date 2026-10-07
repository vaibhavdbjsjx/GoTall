#if os(iOS)
import SwiftUI
import GrowthCore
import DesignSystem

struct HabitsView: View {
    let repository: AppRepository

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    if let profile = repository.activeProfile {
                        let state = DashboardBuilder(now: Date(), calendar: .current).build(for: profile)
                        HabitBaselineSection(habits: state.habits)
                    }
                    EmptyStateView(
                        systemImage: "checklist",
                        title: "Daily check-ins are on the way",
                        message: "Soon you'll be able to log sleep, activity, eating and posture in a few taps and see how routines change. Habits support healthy development. They don't add height."
                    )
                    .dsSurface()
                }
                .padding(.horizontal, DS.Spacing.page)
                .padding(.vertical, DS.Spacing.md)
            }
            .dsPageBackground()
            .navigationTitle("Habits")
            .toolbar { ToolbarItem(placement: .topBarLeading) { ProfileSwitcher(repository: repository) } }
        }
    }
}

struct ProfileView: View {
    let repository: AppRepository
    @State private var showsAddProfile = false
    @State private var confirmsDelete = false
    @State private var deleteFailed = false
    private let entitlements: EntitlementProviding = DevelopmentEntitlements()

    var body: some View {
        NavigationStack {
            List {
                Section("Profiles") {
                    ForEach(repository.profiles) { profile in
                        Button {
                            repository.setActiveProfile(profile.id)
                        } label: {
                            HStack {
                                Label(profile.displayLabel, systemImage: profile.subject == .child ? "figure.child" : "person")
                                    .foregroundStyle(DS.Colors.textPrimary)
                                Spacer()
                                if profile.id == repository.activeProfile?.id {
                                    Image(systemName: "checkmark").foregroundStyle(DS.Colors.accent)
                                }
                            }
                        }
                        .accessibilityAddTraits(profile.id == repository.activeProfile?.id ? .isSelected : [])
                    }
                    // Multiple profiles is a planned Premium feature; gated through the entitlement boundary.
                    if entitlements.isUnlocked(.multipleProfiles) {
                        Button {
                            showsAddProfile = true
                        } label: {
                            Label("Add a child", systemImage: "plus.circle")
                        }
                    }
                }

                if let profile = repository.activeProfile {
                    Section("Units") {
                        Picker("Height unit", selection: Binding(
                            get: { profile.unitPreference },
                            set: { repository.setUnitPreference($0, for: profile.id) }
                        )) {
                            Text("Centimetres").tag(HeightUnit.centimeters)
                            Text("Feet and inches").tag(HeightUnit.feetInches)
                        }
                    }

                    let summary = ProfileSummary(profile: profile, now: Date(), calendar: .current)
                    ForEach(summary.sections) { section in
                        Section(section.title) {
                            ForEach(section.rows) { row in
                                LabeledContent(row.label, value: row.value)
                            }
                        }
                    }
                }

                Section("Privacy") {
                    Label("Stored only on this device", systemImage: "iphone")
                    Label("No ads and no cross-app tracking", systemImage: "hand.raised")
                    Button(role: .destructive) {
                        confirmsDelete = true
                    } label: {
                        Label("Delete all data", systemImage: "trash")
                    }
                }

                Section {
                    LabeledContent("App", value: BrandConfig.current.displayName)
                    Text("This app helps you track and understand growth. It doesn't diagnose. For health concerns, talk to a doctor.")
                        .font(DS.Typography.footnote)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
            .navigationTitle("Profile")
            .confirmationDialog("Delete all data?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) {
                    do { try repository.deleteAllData() } catch { deleteFailed = true }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes every profile and measurement from this device. It can't be undone.")
            }
            .alert("Couldn't delete data", isPresented: $deleteFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please try again.")
            }
            .fullScreenCover(isPresented: $showsAddProfile) {
                OnboardingHost(repository: repository, mode: .additionalProfile,
                               onCancel: { showsAddProfile = false },
                               onFinish: { showsAddProfile = false })
            }
        }
    }
}
#endif
