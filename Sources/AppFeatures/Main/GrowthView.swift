#if os(iOS)
import SwiftUI
import Charts
import GrowthCore
import DesignSystem

struct GrowthView: View {
    let repository: AppRepository
    @State private var showsAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if let profile = repository.activeProfile {
                    content(for: profile)
                } else {
                    LoadingStateView()
                }
            }
            .dsPageBackground()
            .navigationTitle("Growth")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { ProfileSwitcher(repository: repository) }
                ToolbarItem(placement: .primaryAction) {
                    Button { showsAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add measurement")
                }
            }
            .sheet(isPresented: $showsAdd) {
                if let profile = repository.activeProfile {
                    AddMeasurementSheet(repository: repository, profile: profile)
                }
            }
        }
    }

    private func content(for profile: GrowthProfile) -> some View {
        let measurements = profile.sortedMeasurements
        let unit = profile.unitPreference
        return List {
            Section {
                MeasurementChart(measurements: measurements, unit: unit)
                    .listRowInsets(EdgeInsets(top: DS.Spacing.md, leading: DS.Spacing.md, bottom: DS.Spacing.md, trailing: DS.Spacing.md))
            } footer: {
                Text("Your own measurements. CDC percentile lines arrive with the growth-reference update.")
            }

            Section("History") {
                ForEach(measurements.reversed()) { measurement in
                    MeasurementRow(
                        value: HeightFormatter.string(centimeters: measurement.heightCm, unit: unit),
                        accessibleValue: HeightFormatter.accessibleString(centimeters: measurement.heightCm, unit: unit),
                        date: DisplayFormat.day(measurement.date, calendar: .current),
                        detail: measurement.method.title
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if measurements.count > 1 {
                            Button(role: .destructive) {
                                repository.deleteMeasurement(measurement.id, from: profile.id, at: Date())
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

/// Plots only the person's real measurements. Shows an explanatory empty state until there are two points.
struct MeasurementChart: View {
    let measurements: [HeightMeasurement]
    let unit: HeightUnit

    var body: some View {
        if measurements.count < 2 {
            EmptyStateView(systemImage: "chart.xyaxis.line", title: "Your chart starts with two measurements",
                           message: "Add another measurement in a few weeks and the line will appear here.")
        } else {
            Chart(measurements) { measurement in
                LineMark(x: .value("Date", measurement.date), y: .value("Height", displayValue(measurement.heightCm)))
                    .foregroundStyle(DS.Colors.accent)
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Date", measurement.date), y: .value("Height", displayValue(measurement.heightCm)))
                    .foregroundStyle(DS.Colors.accent)
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxisLabel(unit == .centimeters ? "cm" : "in")
            .frame(height: 220)
            .accessibilityLabel("Height over time")
            .accessibilityValue(summary)
        }
    }

    private func displayValue(_ centimeters: Double) -> Double {
        unit == .centimeters ? centimeters : centimeters / HeightConversion.centimetersPerInch
    }

    private var summary: String {
        guard let first = measurements.first, let last = measurements.last else { return "" }
        return "\(measurements.count) measurements, from \(HeightFormatter.accessibleString(centimeters: first.heightCm, unit: unit)) to \(HeightFormatter.accessibleString(centimeters: last.heightCm, unit: unit))"
    }
}

struct AddMeasurementSheet: View {
    let repository: AppRepository
    let profile: GrowthProfile
    @Environment(\.dismiss) private var dismiss
    @State private var centimeters: Double?
    @State private var unit: HeightUnit
    @State private var date: Date? = Date()
    @State private var method: MeasurementMethod = .home

    init(repository: AppRepository, profile: GrowthProfile) {
        self.repository = repository
        self.profile = profile
        _unit = State(initialValue: profile.unitPreference)
        _centimeters = State(initialValue: profile.latestMeasurement?.heightCm)
    }

    private var isValid: Bool { HeightValidation.validate(centimeters) == .valid && date != nil }

    var body: some View {
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
                    if case .tooShort = HeightValidation.validate(centimeters) {
                        InfoBanner("That looks too short. Check the number and the unit.", tone: .caution)
                    } else if case .tooTall = HeightValidation.validate(centimeters) {
                        InfoBanner("That looks too tall. Check the number and the unit.", tone: .caution)
                    }
                }
                .padding(DS.Spacing.page)
            }
            .dsPageBackground()
            .navigationTitle("Add measurement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let centimeters, let date else { return }
                        repository.addMeasurement(HeightMeasurement(date: date, heightCm: centimeters, method: method, origin: .manual),
                                                  to: profile.id, at: Date())
                        if unit != profile.unitPreference { repository.setUnitPreference(unit, for: profile.id) }
                        dismiss()
                    }
                    .disabled(!isValid)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                }
            }
        }
    }
}
#endif
