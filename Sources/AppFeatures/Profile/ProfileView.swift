#if os(iOS)
import SwiftUI
import StoreKit
import GrowthCore
import DesignSystem

/// Personal hub, grouped by purpose: who this is, Premium, tools (reports, reminders), profiles,
/// growth data, preferences, privacy & data, about.
struct ProfileView: View {
    let repository: AppRepository
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(AppNavigator.self) private var navigator
    @Environment(AccountStore.self) private var account
    @AppStorage("appearance") private var appearance = AppAppearance.dark.rawValue
    @State private var editingProfile: GrowthProfile?
    @State private var showsSwitcher = false
    @State private var confirmsDeleteAll = false
    @State private var deleteFailed = false
    @State private var exportURL: URL?
    @State private var exportFailed = false
    @State private var showsManageSubscriptions = false
    @State private var restoring = false
    @State private var restoreMessage: String?
    @State private var path: [ProfileDestination] = []
    @State private var showsAssistant = false
    @State private var legal: LegalDocument?
    @Environment(\.openURL) private var openURL

    enum ProfileDestination: Hashable { case report, reminders, account }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if let profile = repository.activeProfile {
                    Section {
                        ProfileHeaderCard(profile: profile, onEdit: { editingProfile = profile })
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }

                    premiumSection

                    if account.isAvailable {
                        Section("Account") {
                            NavigationLink(value: ProfileDestination.account) {
                                row(account.isSignedIn ? (account.session?.email ?? "Signed in") : "Sign in to back up",
                                    symbol: account.isSignedIn ? "person.crop.circle.badge.checkmark" : "person.crop.circle",
                                    value: account.isSignedIn ? (account.lastBackup == nil ? "Not backed up" : "Backed up") : "Optional")
                            }
                            .accessibilityIdentifier("profile.account")
                        }
                    }

                    Section("Tools") {
                        Button { showsAssistant = true } label: {
                            row(BrandConfig.current.assistantName, symbol: "sparkles", value: nil)
                        }
                        .accessibilityIdentifier("profile.ask")
                        NavigationLink(value: ProfileDestination.report) {
                            HStack {
                                row("Doctor-ready report", symbol: "doc.richtext", value: nil)
                                if !entitlements.isPremium { PremiumBadge() }
                            }
                        }
                        .accessibilityIdentifier("profile.reports")
                        NavigationLink(value: ProfileDestination.reminders) {
                            row("Reminders", symbol: "bell", value: repository.snapshot.notificationPreferences.anyEnabled ? "On" : "Off")
                        }
                        .accessibilityIdentifier("profile.reminders")
                        Button { navigator.showsWeeklySummary = true } label: {
                            row("Your week", symbol: "calendar", value: nil)
                        }
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
                    }
                }

                Section {
                    if account.isSignedIn {
                        Label("On this device, backed up to your account", systemImage: "icloud")
                    } else {
                        Label("Stored only on this device", systemImage: "iphone")
                    }
                    Label("No ads and no cross-app tracking", systemImage: "hand.raised")
                    if let exportURL {
                        ShareLink(item: exportURL) { Label("Share exported file", systemImage: "square.and.arrow.up") }
                    } else {
                        Button { prepareExport() } label: { Label("Export my data", systemImage: "square.and.arrow.up") }
                    }
                    Button(role: .destructive) { confirmsDeleteAll = true } label: { Label("Delete all data", systemImage: "trash") }
                } header: { Text("Privacy & data") } footer: {
                    Text("Export creates a readable JSON file of every profile and measurement. Nothing is uploaded unless you sign in to back up. Deleting data doesn't cancel a subscription; manage that in Apple's subscription settings.")
                }

                Section("About") {
                    Button { legal = .privacy } label: { row("Privacy Policy", symbol: "hand.raised", value: nil) }
                        .accessibilityIdentifier("profile.privacyPolicy")
                    Button { legal = .terms } label: { row("Terms of Use", symbol: "doc.text", value: nil) }
                    if let support = BrandConfig.current.supportURL {
                        Button { openURL(support) } label: { row("Help & support", symbol: "questionmark.circle", value: nil) }
                    }
                    LabeledContent("Version", value: Self.versionText)
                    Text("\(BrandConfig.current.displayName) helps you track and understand growth. It doesn't diagnose. For health concerns, talk to a doctor.")
                        .font(DS.Typography.footnote)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(DS.Colors.background)
            .navigationTitle("Profile")
            .navigationDestination(for: ProfileDestination.self) { destination in
                switch destination {
                case .report: ReportPreviewView(repository: repository)
                case .reminders: NotificationSettingsView(repository: repository)
                case .account: AccountView(repository: repository)
                }
            }
            .manageSubscriptionsSheet(isPresented: $showsManageSubscriptions)
            .onChange(of: showsManageSubscriptions) { _, showing in
                if !showing { Task { await entitlements.refresh() } }
            }
            .confirmationDialog("Delete all data?", isPresented: $confirmsDeleteAll, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) {
                    do { try repository.deleteAllData() } catch { deleteFailed = true }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes every profile and measurement from this device. It can't be undone. A Gromax Pro subscription isn't cancelled by deleting data.")
            }
            .alert("Couldn't delete data", isPresented: $deleteFailed) { Button("OK", role: .cancel) {} } message: { Text("Please try again.") }
            .alert("Couldn't export", isPresented: $exportFailed) { Button("OK", role: .cancel) {} } message: { Text("Please try again.") }
            .sheet(item: $editingProfile) { profile in
                EditProfileView(repository: repository, profile: profile, focus: nil)
            }
            .sheet(item: $legal) { LegalDocumentView(document: $0) }
            .sheet(isPresented: $showsAssistant) { AssistantView(repository: repository).presentationDragIndicator(.visible) }
            .sheet(isPresented: $showsSwitcher) {
                ProfileSwitcherSheet(repository: repository).presentationDetents([.medium, .large])
            }
            .onAppear {
                #if DEBUG
                if UserDefaults.standard.bool(forKey: "openReport"), path.isEmpty { path = [.report] }
                if UserDefaults.standard.bool(forKey: "openNotificationSettings"), path.isEmpty { path = [.reminders] }
                #endif
            }
        }
    }

    @ViewBuilder
    private var premiumSection: some View {
        let state = entitlements.state
        Section {
            SubscriptionCard(title: BrandConfig.current.displayName + " Pro",
                             detail: entitlements.statusDescription(),
                             isPremium: entitlements.isPremium,
                             badge: badge(for: state.status),
                             actionTitle: entitlements.isPremium ? nil : "Explore Gromax Pro",
                             action: entitlements.isPremium ? nil : { navigator.showPaywall(.general) })
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .animation(Motion.standard, value: entitlements.isPremium)
        }
        Section {
            if state.status != .none {
                ManageSubscriptionRow { showsManageSubscriptions = true }
            }
            Button {
                restoring = true
                Task {
                    let outcome = await entitlements.restore()
                    restoring = false
                    switch outcome {
                    case .restored: restoreMessage = "Gromax Pro restored."
                    case .nothingToRestore: restoreMessage = "No previous purchase was found for this Apple Account."
                    case .failed(let message): restoreMessage = message
                    }
                }
            } label: {
                HStack {
                    Label("Restore purchases", systemImage: "arrow.clockwise").foregroundStyle(DS.Colors.textPrimary)
                    Spacer()
                    if restoring { ProgressView() }
                }
            }
            .disabled(restoring)
            .accessibilityIdentifier("profile.restore")
        } footer: {
            if let restoreMessage { Text(restoreMessage).accessibilityIdentifier("profile.restoreMessage") }
        }
    }

    static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func badge(for status: EntitlementState.Status) -> String? {
        switch status {
        case .active: return "Active"
        case .cancelled: return "Ending"
        case .gracePeriod, .billingRetry: return "Payment issue"
        case .expired: return "Ended"
        case .none, .revoked: return nil
        }
    }

    private func row(_ title: String, symbol: String, value: String?) -> some View {
        HStack {
            Label(title, systemImage: symbol).foregroundStyle(DS.Colors.textPrimary)
            Spacer()
            if let value { Text(value).foregroundStyle(DS.Colors.textSecondary).hiddenAtAccessibilitySizes() }
        }
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

#endif
