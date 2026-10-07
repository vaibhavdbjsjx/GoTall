#if os(iOS)
import SwiftUI
import GrowthCore
import DesignSystem

enum MeasurementEditorRoute: Identifiable {
    case add
    case edit(HeightMeasurement)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let m): return m.id.uuidString
        }
    }
}

/// Add or edit one measurement. Blocking issues disable Save; warnings explain and allow saving.
struct MeasurementEditorSheet: View {
    let repository: AppRepository
    let profile: GrowthProfile
    let route: MeasurementEditorRoute

    @Environment(\.dismiss) private var dismiss
    @State private var centimeters: Double?
    @State private var unit: HeightUnit
    @State private var date: Date?
    @State private var method: MeasurementMethod
    @State private var confirmsDelete = false
    @State private var showsGuide = false

    init(repository: AppRepository, profile: GrowthProfile, route: MeasurementEditorRoute) {
        self.repository = repository
        self.profile = profile
        self.route = route
        _unit = State(initialValue: profile.unitPreference)
        switch route {
        case .add:
            _centimeters = State(initialValue: profile.latestMeasurement?.heightCm)
            _date = State(initialValue: Date())
            _method = State(initialValue: .home)
        case .edit(let m):
            _centimeters = State(initialValue: m.heightCm)
            _date = State(initialValue: m.date)
            _method = State(initialValue: m.method)
        }
    }

    private var editingID: UUID? {
        if case .edit(let m) = route { return m.id }
        return nil
    }

    private var check: MeasurementCheck {
        MeasurementValidator.check(heightCm: centimeters, date: date ?? Date(), editingID: editingID, profile: profile, today: Date(), calendar: .current)
    }

    var body: some View {
        let check = self.check
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    AppCard { HeightInput(centimeters: $centimeters, unit: $unit) }
                    AppCard {
                        DateInput("Date measured", date: $date, in: profile.birthDate...Date(), defaultDate: Date())
                    }
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        FieldLabel("How was this measured?")
                        SegmentedChoice("Method", options: MeasurementMethod.allCases, selection: $method) { $0.title }
                    }
                    ForEach(Array(check.issues.enumerated()), id: \.offset) { _, issue in
                        InfoBanner(MeasurementValidator.message(issue), tone: .caution)
                    }
                    ForEach(Array(check.warnings.enumerated()), id: \.offset) { _, warning in
                        InfoBanner(MeasurementValidator.message(warning, unit: unit), tone: .info)
                    }
                    Button { showsGuide = true } label: {
                        Label("How to measure accurately", systemImage: "ruler")
                            .font(DS.Typography.subheadline.weight(.semibold))
                            .frame(minHeight: DS.minimumTapTarget)
                    }
                    .foregroundStyle(DS.Colors.accent)

                    if editingID != nil && profile.measurements.count > 1 {
                        AppButton("Delete measurement", systemImage: "trash", kind: .destructive) { confirmsDelete = true }
                    }
                }
                .padding(DS.Spacing.page)
            }
            .dsPageBackground()
            .navigationTitle(editingID == nil ? "Add measurement" : "Edit measurement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!check.canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                }
            }
            .confirmationDialog("Delete this measurement?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let id = editingID { repository.deleteMeasurement(id, from: profile.id, at: Date()) }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showsGuide) { MeasurementGuideView() }
        }
    }

    private func save() {
        guard let centimeters, let date, check.canSave else { return }
        let day = Calendar.current.startOfDay(for: date)
        switch route {
        case .add:
            repository.addMeasurement(HeightMeasurement(date: day, heightCm: centimeters, method: method, origin: .manual), to: profile.id, at: Date())
        case .edit(let original):
            var updated = original
            updated.date = day
            updated.heightCm = HeightConversion.rounded(centimeters)
            updated.method = method
            repository.updateMeasurement(updated, in: profile.id, at: Date())
        }
        if unit != profile.unitPreference { repository.setUnitPreference(unit, for: profile.id) }
        dismiss()
    }
}

/// Full history: newest first, grouped by year, with percentile at each point. Tap to edit, swipe to delete.
struct MeasurementHistoryView: View {
    let repository: AppRepository
    @State private var editor: MeasurementEditorRoute?

    var body: some View {
        Group {
            if let profile = repository.activeProfile {
                let analysis = GrowthAnalyzer(now: Date(), calendar: .current).analyze(profile)
                let percentileByDay = Dictionary(uniqueKeysWithValues: analysis.series.points.map { ($0.date, $0) })
                let grouped = Dictionary(grouping: profile.sortedMeasurements.reversed()) { Calendar.current.component(.year, from: $0.date) }
                List {
                    ForEach(grouped.keys.sorted(by: >), id: \.self) { year in
                        Section(String(year)) {
                            ForEach(grouped[year] ?? []) { m in
                                let point = percentileByDay[Calendar.current.startOfDay(for: m.date)]
                                Button { editor = .edit(m) } label: {
                                    MeasurementRow(
                                        value: HeightFormatter.string(centimeters: m.heightCm, unit: profile.unitPreference),
                                        accessibleValue: HeightFormatter.accessibleString(centimeters: m.heightCm, unit: profile.unitPreference),
                                        date: DisplayFormat.day(m.date, calendar: .current),
                                        detail: [m.method.title,
                                                 point?.percentile.map { PercentileFormatter.phrase($0.percentile) },
                                                 (point?.count ?? 1) > 1 ? "averaged with \((point?.count ?? 1) - 1) other" : nil]
                                            .compactMap { $0 }.joined(separator: " · ")
                                    )
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if profile.measurements.count > 1 {
                                        Button(role: .destructive) {
                                            repository.deleteMeasurement(m.id, from: profile.id, at: Date())
                                        } label: { Label("Delete", systemImage: "trash") }
                                    }
                                }
                            }
                        }
                    }
                    Section {
                        Text("Measurements on the same day are averaged. A profile always keeps at least one measurement.")
                            .font(DS.Typography.footnote)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                }
                .scrollContentBackground(.hidden)
                .sheet(item: $editor) { route in
                    MeasurementEditorSheet(repository: repository, profile: profile, route: route)
                }
            } else {
                LoadingStateView()
            }
        }
        .dsPageBackground()
        .navigationTitle("Measurements")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editor = .add } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add measurement")
            }
        }
    }
}
#endif
