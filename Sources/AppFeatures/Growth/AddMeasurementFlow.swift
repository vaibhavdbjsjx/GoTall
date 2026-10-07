#if os(iOS)
import SwiftUI
import GrowthCore
import GrowthEngine
import DesignSystem

/// Four short steps (height → method → date → review), then an honest success screen that celebrates
/// better data and consistency, never height gained.
struct AddMeasurementFlow: View {
    enum Step: Int, CaseIterable {
        case height, method, date, review
        var title: String {
            switch self {
            case .height: return "How tall today?"
            case .method: return "How was it measured?"
            case .date: return "When was it measured?"
            case .review: return "Check and save"
            }
        }
    }

    let repository: AppRepository
    let profile: GrowthProfile

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: Step = .height
    @State private var forward = true
    @State private var centimeters: Double?
    @State private var unit: HeightUnit
    @State private var method: MeasurementMethod = .home
    @State private var date: Date = Date()
    @State private var outcome: MeasurementOutcome?
    @State private var showsGuide = false

    init(repository: AppRepository, profile: GrowthProfile) {
        self.repository = repository
        self.profile = profile
        _unit = State(initialValue: profile.unitPreference)
        _centimeters = State(initialValue: profile.latestMeasurement?.heightCm)
    }

    private var check: MeasurementCheck {
        MeasurementValidator.check(heightCm: centimeters, date: date, editingID: nil, profile: profile, today: Date(), calendar: .current)
    }

    private var canContinue: Bool {
        switch step {
        case .height: return HeightValidation.validate(centimeters) == .valid
        case .method: return true
        case .date: return !check.issues.contains(.dateInFuture) && !check.issues.contains(.dateBeforeBirth)
        case .review: return check.canSave
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let outcome {
                    MeasurementSuccessView(outcome: outcome, repository: repository, profileID: profile.id) { dismiss() }
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    stepContainer
                }
            }
            .animation(Motion.resolved(Motion.page, reduceMotion: reduceMotion), value: outcome != nil)
            .dsPageBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if outcome == nil {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 6) {
                            ForEach(Step.allCases, id: \.self) { s in
                                Capsule().fill(s.rawValue <= step.rawValue ? DS.Colors.accent : DS.Colors.surfaceSecondary)
                                    .frame(width: s == step ? 22 : 8, height: 8)
                            }
                        }
                        .animation(Motion.standard, value: step)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")
                    }
                }
            }
            .sheet(isPresented: $showsGuide) { MeasurementGuideView() }
        }
        .onAppear(perform: applyLaunchOptions)
    }

    private var stepContainer: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    Text(step.title)
                        .font(DS.Typography.question)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    stepContent
                        .id(step)
                        .transition(Motion.stepTransition(forward: forward, reduceMotion: reduceMotion))
                }
                .padding(DS.Spacing.page)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            VStack(spacing: DS.Spacing.xs) {
                AppButton(step == .review ? "Save measurement" : "Continue") { advance() }
                    .disabled(!canContinue)
                if step != .height {
                    AppButton("Back", kind: .tertiary) { move(to: Step(rawValue: step.rawValue - 1)!, forward: false) }
                }
            }
            .padding(.horizontal, DS.Spacing.page)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.background)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .height:
            AppCard { HeightInput(centimeters: $centimeters, unit: $unit) }
            if let issue = check.issues.first(where: { if case .heightOutOfRange = $0 { return true }; return false }), centimeters != nil {
                InfoBanner(MeasurementValidator.message(issue), tone: .caution)
            }
            Button { showsGuide = true } label: {
                Label("How to measure accurately", systemImage: "ruler")
                    .font(DS.Typography.subheadline.weight(.semibold))
                    .frame(minHeight: DS.minimumTapTarget)
            }
            .foregroundStyle(DS.Colors.accent)
        case .method:
            VStack(spacing: DS.Spacing.sm) {
                ForEach(MeasurementMethod.allCases, id: \.self) { m in
                    SelectionCard(title: m.title, detail: methodDetail(m), systemImage: m.symbol, isSelected: method == m) { method = m }
                }
            }
        case .date:
            AppCard(padding: DS.Spacing.xs) {
                DatePicker("Date measured", selection: $date, in: profile.birthDate...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(DS.Colors.accent)
            }
        case .review:
            AppCard(padding: DS.Spacing.lg) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    reviewRow("Height", centimeters.map { HeightFormatter.string(centimeters: $0, unit: unit) } ?? "—", step: .height)
                    Divider()
                    reviewRow("Measured", method.title, step: .method)
                    Divider()
                    reviewRow("Date", DisplayFormat.day(date, calendar: .current), step: .date)
                }
            }
            ForEach(Array(check.warnings.enumerated()), id: \.offset) { _, warning in
                InfoBanner(MeasurementValidator.message(warning, unit: unit), tone: .info)
            }
            ForEach(Array(check.issues.enumerated()), id: \.offset) { _, issue in
                InfoBanner(MeasurementValidator.message(issue), tone: .caution)
            }
        }
    }

    private func methodDetail(_ m: MeasurementMethod) -> String {
        switch m {
        case .home: return "Against a wall, shoes off"
        case .professional: return "Doctor, nurse or school"
        case .estimate: return "A best guess for now"
        }
    }

    private func reviewRow(_ label: String, _ value: String, step target: Step) -> some View {
        HStack {
            Text(label).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
            Spacer()
            Text(value).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
            Button("Edit") { move(to: target, forward: false) }
                .font(DS.Typography.subheadline.weight(.semibold))
                .foregroundStyle(DS.Colors.accent)
                .frame(minWidth: DS.minimumTapTarget, minHeight: DS.minimumTapTarget)
                .accessibilityLabel("Edit \(label.lowercased())")
        }
    }

    private func move(to target: Step, forward: Bool) {
        self.forward = forward
        withAnimation(Motion.resolved(Motion.page, reduceMotion: reduceMotion)) { step = target }
    }

    private func advance() {
        guard canContinue else { return }
        if let next = Step(rawValue: step.rawValue + 1) {
            dismissKeyboard()
            move(to: next, forward: true)
        } else {
            save()
        }
    }

    private func save() {
        guard let centimeters else { return }
        let analyzer = GrowthAnalyzer(now: Date(), calendar: .current)
        let before = analyzer.analyze(profile)
        let measurement = HeightMeasurement(date: Calendar.current.startOfDay(for: date), heightCm: centimeters, method: method, origin: .manual)
        repository.addMeasurement(measurement, to: profile.id, at: Date())
        if unit != profile.unitPreference { repository.setUnitPreference(unit, for: profile.id) }
        if let updated = repository.profiles.first(where: { $0.id == profile.id }) {
            outcome = MeasurementOutcome.compare(before: before, after: analyzer.analyze(updated))
        }
    }

    private func applyLaunchOptions() {
        #if DEBUG
        if let name = UserDefaults.standard.string(forKey: "measurementStep"),
           let target = ["height": Step.height, "method": .method, "date": .date, "review": .review][name] {
            step = target
        }
        if UserDefaults.standard.bool(forKey: "measurementSuccess") {
            centimeters = (profile.latestMeasurement?.heightCm ?? 150) + 1.2
            save()
        }
        #endif
    }
}

struct MeasurementSuccessView: View {
    let outcome: MeasurementOutcome
    let repository: AppRepository
    let profileID: UUID
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            SuccessSeal()
            VStack(spacing: DS.Spacing.xs) {
                Text(outcome.headline)
                    .font(DS.Typography.title)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                Text(outcome.detail)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: DS.Spacing.lg) {
                if let p = outcome.percentileText {
                    stat(value: p.replacingOccurrences(of: " percentile", with: ""), label: "Percentile")
                }
                stat(value: "\(outcome.measurementDays)", label: outcome.measurementDays == 1 ? "Measurement day" : "Measurement days")
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            Spacer()
            AppButton("Done", action: onDone)
        }
        .padding(DS.Spacing.page)
        .accessibilityElement(children: .contain)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(DS.Typography.metricSmall).foregroundStyle(DS.Colors.textPrimary)
            Text(label).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
        }
        .frame(minWidth: 110)
        .accessibilityElement(children: .combine)
    }
}
#endif
