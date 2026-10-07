#if os(iOS)
import SwiftUI
import GrowthCore
import GrowthEngine
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
                HistoryList(repository: repository, profile: profile, onEdit: { editor = .edit($0) })
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

private struct HistoryList: View {
    let repository: AppRepository
    let profile: GrowthProfile
    let onEdit: (HeightMeasurement) -> Void

    private var pointsByDay: [Date: SeriesPoint] {
        let analysis = GrowthAnalyzer(now: Date(), calendar: .current).analyze(profile)
        return Dictionary(uniqueKeysWithValues: analysis.series.points.map { ($0.date, $0) })
    }

    private var years: [(year: Int, items: [HeightMeasurement])] {
        let grouped = Dictionary(grouping: profile.sortedMeasurements.reversed()) { Calendar.current.component(.year, from: $0.date) }
        return grouped.keys.sorted(by: >).map { (year: $0, items: grouped[$0] ?? []) }
    }

    var body: some View {
        let points = pointsByDay
        List {
            ForEach(years, id: \.year) { group in
                Section(String(group.year)) {
                    ForEach(group.items) { m in
                        HistoryRow(measurement: m, point: points[Calendar.current.startOfDay(for: m.date)], unit: profile.unitPreference)
                            .contentShape(Rectangle())
                            .onTapGesture { onEdit(m) }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityHint("Edit this measurement")
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
    }
}

private struct HistoryRow: View {
    let measurement: HeightMeasurement
    let point: SeriesPoint?
    let unit: HeightUnit

    private var detail: String {
        var parts: [String] = [measurement.method.title]
        if let p = point?.percentile { parts.append(PercentileFormatter.phrase(p.percentile)) }
        if let count = point?.count, count > 1 { parts.append("averaged with \(count - 1) other") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        MeasurementRow(
            value: HeightFormatter.string(centimeters: measurement.heightCm, unit: unit),
            accessibleValue: HeightFormatter.accessibleString(centimeters: measurement.heightCm, unit: unit),
            date: DisplayFormat.day(measurement.date, calendar: .current),
            detail: detail
        )
    }
}
#endif
