#if os(iOS)
import SwiftUI
import GrowthCore
import DesignSystem

struct ProfileView: View {
    let repository: AppRepository
    @State private var showsAddProfile = false
    @State private var editingProfile: GrowthProfile?
    @State private var confirmsDeleteAll = false
    @State private var deleteFailed = false
    private let entitlements: EntitlementProviding = DevelopmentEntitlements()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(repository.profiles) { profile in
                        ProfileRow(profile: profile, isActive: profile.id == repository.activeProfile?.id,
                                   onSelect: { withAnimation(Motion.standard) { repository.setActiveProfile(profile.id) } },
                                   onEdit: { editingProfile = profile })
                    }
                    // Multiple profiles is a planned Premium feature, gated through the entitlement boundary (unlocked in development).
                    if entitlements.isUnlocked(.multipleProfiles) {
                        Button { showsAddProfile = true } label: {
                            Label("Add a child", systemImage: "plus.circle.fill")
                                .font(DS.Typography.body.weight(.semibold))
                        }
                        .frame(minHeight: DS.minimumTapTarget)
                    }
                } header: {
                    Text("Profiles")
                } footer: {
                    Text("Each profile has its own measurements, chart and estimate.")
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
                }

                Section("Privacy") {
                    Label("Stored only on this device", systemImage: "iphone")
                    Label("No ads and no cross-app tracking", systemImage: "hand.raised")
                    Button(role: .destructive) { confirmsDeleteAll = true } label: {
                        Label("Delete all data", systemImage: "trash")
                    }
                }

                Section {
                    LabeledContent("App", value: BrandConfig.current.displayName)
                    LabeledContent("Growth reference", value: "CDC 2000, ages 2–20")
                    Text("This app helps you track and understand growth. It doesn't diagnose. For health concerns, talk to a doctor.")
                        .font(DS.Typography.footnote)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
            .navigationTitle("Profile")
            .confirmationDialog("Delete all data?", isPresented: $confirmsDeleteAll, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) {
                    do { try repository.deleteAllData() } catch { deleteFailed = true }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes every profile and measurement from this device. It can't be undone.")
            }
            .alert("Couldn't delete data", isPresented: $deleteFailed) {
                Button("OK", role: .cancel) {}
            } message: { Text("Please try again.") }
            .sheet(item: $editingProfile) { profile in
                EditProfileView(repository: repository, profile: profile, focus: nil)
            }
            .fullScreenCover(isPresented: $showsAddProfile) {
                OnboardingHost(repository: repository, mode: .additionalProfile,
                               onCancel: { showsAddProfile = false },
                               onFinish: { showsAddProfile = false })
            }
        }
    }
}

struct ProfileRow: View {
    let profile: GrowthProfile
    let isActive: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Button(action: onSelect) {
                HStack(spacing: DS.Spacing.sm) {
                    ProfileAvatar(profile: profile, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.subject == .myself ? "Me" : (profile.nickname ?? "Child"))
                            .font(DS.Typography.body.weight(.semibold))
                            .foregroundStyle(DS.Colors.textPrimary)
                        Text(subtitle).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                    }
                    Spacer()
                    if isActive {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(DS.Colors.accent).accessibilityHidden(true)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
            Button("Edit", action: onEdit)
                .buttonStyle(.borderless)
                .font(DS.Typography.subheadline.weight(.semibold))
                .foregroundStyle(DS.Colors.accent)
                .frame(minWidth: DS.minimumTapTarget, minHeight: DS.minimumTapTarget)
                .accessibilityLabel("Edit \(profile.displayLabel)")
        }
    }

    private var subtitle: String {
        let age = profile.age(on: Date(), calendar: .current).map { "\($0.years) years" } ?? ""
        let latest = profile.latestMeasurement.map { HeightFormatter.string(centimeters: $0.heightCm, unit: profile.unitPreference) } ?? ""
        return [age, latest].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
#endif
