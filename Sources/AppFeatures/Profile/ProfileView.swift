#if os(iOS)
import SwiftUI
import GrowthCore
import DesignSystem

/// Personal settings hub: who this is, their growth data, preferences, privacy, and what's coming.
struct ProfileView: View {
    let repository: AppRepository
    @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue
    @State private var editingProfile: GrowthProfile?
    @State private var showsSwitcher = false
    @State private var confirmsDeleteAll = false
    @State private var deleteFailed = false
    @State private var exportURL: URL?
    @State private var exportFailed = false

    var body: some View {
        NavigationStack {
            List {
                if let profile = repository.activeProfile {
                    Section {
                        ProfileHeaderCard(profile: profile, onEdit: { editingProfile = profile })
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }

                    Section("Profiles") {
                        Button { showsSwitcher = true } label: {
                            row("Switch or add a profile", symbol: "person.2", value: repository.profiles.count > 1 ? "\(repository.profiles.count) profiles" : nil)
                        }
                    }

                    Section("Growth") {
                        NavigationLink { MeasurementHistoryView(repository: repository) } label: {
                            row("Measurements", symbol: "ruler", value: "\(profile.measurements.count)")
                        }
                        Button { editingProfile = profile } label: {
                            row("Family heights and details", symbol: "person.text.rectangle", value: nil)
                        }
                        LabeledContent { Text("CDC 2000, ages 2–20") } label: { Label("Growth reference", systemImage: "chart.xyaxis.line") }
                    }

                    Section("Preferences") {
                        Picker(selection: Binding(get: { profile.unitPreference }, set: { repository.setUnitPreference($0, for: profile.id) })) {
                            Text("Centimetres").tag(HeightUnit.centimeters)
                            Text("Feet and inches").tag(HeightUnit.feetInches)
                        } label: { Label("Height unit", systemImage: "textformat.123") }
                        Picker(selection: $appearance) {
                            ForEach(AppAppearance.allCases) { Text($0.title).tag($0.rawValue) }
                        } label: { Label("Appearance", systemImage: "circle.lefthalf.filled") }
                        NavigationLink { NotificationSettingsView(repository: repository) } label: {
                            row("Reminders", symbol: "bell", value: repository.snapshot.notificationPreferences.anyEnabled ? "On" : "Off")
                        }
                    }
                }

                Section {
                    Label("Stored only on this device", systemImage: "iphone")
                    Label("No ads and no cross-app tracking", systemImage: "hand.raised")
                    if let exportURL {
                        ShareLink(item: exportURL) { Label("Share exported file", systemImage: "square.and.arrow.up") }
                    } else {
                        Button { prepareExport() } label: { Label("Export my data", systemImage: "square.and.arrow.up") }
                    }
                    Button(role: .destructive) { confirmsDeleteAll = true } label: { Label("Delete all data", systemImage: "trash") }
                } header: { Text("Privacy") } footer: {
                    Text("Export creates a readable JSON file of every profile and measurement. Nothing is uploaded.")
                }

                Section {
                    plannedRow("Doctor-ready growth report", symbol: "doc.richtext")
                    plannedRow("Advanced growth insights", symbol: "sparkles")
                    plannedRow("Family plan", symbol: "person.3")
                } header: { Text("Coming later") } footer: {
                    Text("Your growth profile, chart, estimate and history stay free.")
                }

                Section {
                    LabeledContent("App", value: BrandConfig.current.displayName)
                    Text("This app helps you track and understand growth. It doesn't diagnose. For health concerns, talk to a doctor.")
                        .font(DS.Typography.footnote)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(DS.Colors.background)
            .navigationTitle("Profile")
            .confirmationDialog("Delete all data?", isPresented: $confirmsDeleteAll, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) {
                    do { try repository.deleteAllData() } catch { deleteFailed = true }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes every profile and measurement from this device. It can't be undone.")
            }
            .alert("Couldn't delete data", isPresented: $deleteFailed) { Button("OK", role: .cancel) {} } message: { Text("Please try again.") }
            .alert("Couldn't export", isPresented: $exportFailed) { Button("OK", role: .cancel) {} } message: { Text("Please try again.") }
            .sheet(item: $editingProfile) { profile in
                EditProfileView(repository: repository, profile: profile, focus: nil)
            }
            .sheet(isPresented: $showsSwitcher) {
                ProfileSwitcherSheet(repository: repository).presentationDetents([.medium, .large])
            }
        }
    }

    private func row(_ title: String, symbol: String, value: String?) -> some View {
        HStack {
            Label(title, systemImage: symbol).foregroundStyle(DS.Colors.textPrimary)
            Spacer()
            if let value { Text(value).foregroundStyle(DS.Colors.textSecondary).hiddenAtAccessibilitySizes() }
        }
    }

    private func plannedRow(_ title: String, symbol: String) -> some View {
        HStack {
            Label(title, systemImage: symbol).foregroundStyle(DS.Colors.textSecondary)
            Spacer()
            Badge("Planned")
        }
        .accessibilityElement(children: .combine)
    }

    private func prepareExport() {
        do {
            let data = try DataExporter.exportJSON(repository.snapshot)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(DataExporter.fileName(now: Date(), calendar: .current))
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            exportURL = url
        } catch {
            exportFailed = true
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

private struct ProfileHeaderCard: View {
    let profile: GrowthProfile
    let onEdit: () -> Void

    var body: some View {
        let summary = ProfileCardSummary(profile: profile, now: Date(), calendar: .current)
        HStack(spacing: DS.Spacing.md) {
            ProfileAvatar(profile: profile, size: 60)
                .hiddenAtAccessibilitySizes()
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.name).font(DS.Typography.title).foregroundStyle(DS.Colors.textPrimary)
                Text([summary.ageText, summary.heightText].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                Text(summary.statusText).font(DS.Typography.caption).foregroundStyle(DS.Colors.accent)
            }
            Spacer(minLength: 0)
            Button("Edit", action: onEdit)
                .font(DS.Typography.subheadline.weight(.semibold))
                .foregroundStyle(DS.Colors.accent)
                .frame(minWidth: DS.minimumTapTarget, minHeight: DS.minimumTapTarget)
                .buttonStyle(.borderless)
        }
        .padding(DS.Spacing.lg)
        .heroSurface()
    }
}

/// Reminder choices. Saved now; delivery starts once notifications are wired up (Phase 5).
struct NotificationSettingsView: View {
    let repository: AppRepository

    var body: some View {
        let prefs = repository.snapshot.notificationPreferences
        Form {
            Section {
                Toggle(isOn: binding(\.measurementReminders, prefs)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Measurement reminders")
                        Text("When a new measurement is due, every few months.").font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                    }
                }
                Toggle(isOn: binding(\.dailyCheckIn, prefs)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily check-in")
                        Text("One gentle note a day for habits. Never about height.").font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                    }
                }
                if prefs.dailyCheckIn {
                    DatePicker("Time", selection: Binding(
                        get: { Calendar.current.date(bySettingHour: prefs.dailyCheckInTime.hour, minute: prefs.dailyCheckInTime.minute, second: 0, of: Date()) ?? Date() },
                        set: { date in
                            var p = repository.snapshot.notificationPreferences
                            let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                            p.dailyCheckInTime = TimeOfDay(hour: c.hour ?? 19, minute: c.minute ?? 0)
                            repository.setNotificationPreferences(p)
                        }
                    ), displayedComponents: .hourAndMinute)
                }
                Toggle(isOn: binding(\.weeklySummary, prefs)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Weekly summary")
                        Text("Sunday evening: the week's check-ins and what's next.").font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                    }
                }
            } footer: {
                Text("Your choices are saved on this device. Reminders start in an upcoming update, and iOS will ask for permission first. We never send fear- or guilt-based messages.")
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func binding(_ keyPath: WritableKeyPath<NotificationPreferences, Bool>, _ prefs: NotificationPreferences) -> Binding<Bool> {
        Binding(get: { prefs[keyPath: keyPath] }, set: { value in
            var p = repository.snapshot.notificationPreferences
            p[keyPath: keyPath] = value
            repository.setNotificationPreferences(p)
        })
    }
}
#endif
