#if os(iOS)
import SwiftUI
import UIKit
import GrowthCore

/// cm | ft in toggle. Changing the unit never changes the stored value.
public struct UnitToggle: View {
    @Binding var unit: HeightUnit

    public init(unit: Binding<HeightUnit>) {
        self._unit = unit
    }

    public var body: some View {
        SegmentedChoice("Unit", options: HeightUnit.allCases, selection: $unit) { $0 == .centimeters ? "cm" : "ft in" }
            .frame(maxWidth: 180)
            .accessibilityLabel("Height unit")
    }
}

/// Precise height entry: typed value first (fast and exact), ± steppers for fine adjustment,
/// and a slider for people who prefer dragging. Value is stored in cm; `nil` means empty.
public struct HeightInput: View {
    @Binding var centimeters: Double?
    @Binding var unit: HeightUnit
    let range: ClosedRange<Double>
    let showsSlider: Bool
    let label: String

    @State private var cmText = ""
    @State private var feetText = ""
    @State private var inchText = ""
    @FocusState private var focus: Field?

    enum Field { case cm, feet, inches }

    public init(label: String = "Height", centimeters: Binding<Double?>, unit: Binding<HeightUnit>, range: ClosedRange<Double> = HeightValidation.personRange, showsSlider: Bool = true) {
        self.label = label
        self._centimeters = centimeters
        self._unit = unit
        self.range = range
        self.showsSlider = showsSlider
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text(label)
                    .font(DS.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(DS.Colors.textSecondary)
                Spacer()
                UnitToggle(unit: $unit)
            }

            HStack(spacing: DS.Spacing.sm) {
                stepButton(systemImage: "minus", delta: -step, label: "Decrease")
                fields
                    .frame(maxWidth: .infinity)
                stepButton(systemImage: "plus", delta: step, label: "Increase")
            }

            if showsSlider {
                Slider(value: sliderBinding, in: range, step: unit == .centimeters ? 0.5 : HeightConversion.centimetersPerInch / 2)
                    .tint(DS.Colors.accent)
                    .accessibilityLabel(label)
                    .accessibilityValue(centimeters.map { HeightFormatter.accessibleString(centimeters: $0, unit: unit) } ?? "Not set")
            }
        }
        .onAppear(perform: syncText)
        .onChange(of: unit) { _, _ in syncText() }
        // External changes (slider, skip, edit) refresh the fields unless the person is typing.
        .onChange(of: centimeters) { _, _ in if focus == nil { syncText() } }
    }

    private var step: Double { unit == .centimeters ? 0.5 : HeightConversion.centimetersPerInch / 2 }

    @ViewBuilder
    private var fields: some View {
        switch unit {
        case .centimeters:
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField("0.0", text: $cmText)
                    .keyboardType(.decimalPad)
                    .focused($focus, equals: .cm)
                    .multilineTextAlignment(.trailing)
                    .font(DS.Typography.metricLarge)
                    .fixedSize()
                    .accessibilityLabel("\(label) in centimetres")
                    .onChange(of: cmText) { _, text in
                        guard focus == .cm else { return }
                        centimeters = HeightInputParser.centimeters(text)
                    }
                Text("cm").font(DS.Typography.headline).foregroundStyle(DS.Colors.textSecondary)
            }
        case .feetInches:
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField("0", text: $feetText)
                    .keyboardType(.numberPad)
                    .focused($focus, equals: .feet)
                    .multilineTextAlignment(.trailing)
                    .font(DS.Typography.metricLarge)
                    .fixedSize()
                    .accessibilityLabel("\(label), feet")
                Text("ft").font(DS.Typography.headline).foregroundStyle(DS.Colors.textSecondary)
                TextField("0", text: $inchText)
                    .keyboardType(.decimalPad)
                    .focused($focus, equals: .inches)
                    .multilineTextAlignment(.trailing)
                    .font(DS.Typography.metricLarge)
                    .fixedSize()
                    .accessibilityLabel("\(label), inches")
                Text("in").font(DS.Typography.headline).foregroundStyle(DS.Colors.textSecondary)
            }
            .onChange(of: feetText) { _, _ in imperialChanged() }
            .onChange(of: inchText) { _, _ in imperialChanged() }
        }
    }

    private func imperialChanged() {
        guard focus == .feet || focus == .inches else { return }
        centimeters = HeightInputParser.centimeters(feet: feetText, inches: inchText)
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { min(max(centimeters ?? midpoint, range.lowerBound), range.upperBound) },
            set: { newValue in
                centimeters = HeightConversion.rounded(newValue)
                syncText()
            }
        )
    }

    private var midpoint: Double { (range.lowerBound + range.upperBound) / 2 }

    private func stepButton(systemImage: String, delta: Double, label: String) -> some View {
        Button {
            let base = centimeters ?? midpoint
            centimeters = HeightConversion.rounded(min(max(base + delta, range.lowerBound), range.upperBound))
            syncText()
        } label: {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
                .foregroundStyle(DS.Colors.accent)
                .background(DS.Colors.accentSoft, in: Circle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(label) by \(unit == .centimeters ? "half a centimetre" : "half an inch")")
    }

    /// Re-reads text from the stored value (never the other way round), so switching units can't drift the value.
    private func syncText() {
        cmText = HeightInputParser.fieldText(centimeters: centimeters)
        let imperial = HeightInputParser.fieldText(feetInchesFrom: centimeters)
        feetText = imperial.feet
        inchText = imperial.inches
    }
}

/// Dismisses the keyboard from anywhere (used by the keyboard toolbar's Done button).
@MainActor
public func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

/// Date entry with explicit bounds. Uses the compact system picker (accessible, familiar).
public struct DateInput: View {
    let label: String
    @Binding var date: Date?
    let range: ClosedRange<Date>
    let defaultDate: Date

    public init(_ label: String, date: Binding<Date?>, in range: ClosedRange<Date>, defaultDate: Date) {
        self.label = label
        self._date = date
        self.range = range
        self.defaultDate = defaultDate
    }

    public var body: some View {
        DatePicker(label, selection: Binding(
            get: { date ?? defaultDate },
            set: { date = $0 }
        ), in: range, displayedComponents: .date)
        .datePickerStyle(.compact)
        .font(DS.Typography.body)
        .tint(DS.Colors.accent)
        .frame(minHeight: DS.minimumTapTarget)
    }
}

/// Time-of-day entry for sleep baselines.
public struct TimeInput: View {
    let label: String
    @Binding var time: TimeOfDay?
    let defaultTime: TimeOfDay

    public init(_ label: String, time: Binding<TimeOfDay?>, defaultTime: TimeOfDay) {
        self.label = label
        self._time = time
        self.defaultTime = defaultTime
    }

    public var body: some View {
        DatePicker(label, selection: Binding(
            get: { Self.date(from: time ?? defaultTime) },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                time = TimeOfDay(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
            }
        ), displayedComponents: .hourAndMinute)
        .datePickerStyle(.compact)
        .tint(DS.Colors.accent)
        .frame(minHeight: DS.minimumTapTarget)
    }

    static func date(from time: TimeOfDay) -> Date {
        Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date()) ?? Date()
    }
}
#endif
