#if os(iOS)
import SwiftUI
import GrowthCore
import DesignSystem

struct CurrentHeightStepView: View {
    @Bindable var controller: OnboardingController
    let onCancel: (() -> Void)?
    @State private var showsGuide = false

    var body: some View {
        let copy = controller.copy
        StepScaffold(controller: controller, title: copy.heightTitle, subtitle: copy.heightSubtitle, onCancel: onCancel) {
            AppCard {
                HeightInput(centimeters: controller.binding(\.currentHeightCm), unit: controller.binding(\.unit))
            }
            if let message = copy.heightMessage(HeightValidation.validate(controller.draft.currentHeightCm)) {
                InfoBanner(message, tone: .caution)
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                FieldLabel(copy.heightMethodLabel)
                SegmentedChoice(copy.heightMethodLabel, options: MeasurementMethod.allCases,
                                selection: controller.binding(\.currentHeightMethod)) { $0.title }
            }
            Button {
                showsGuide = true
            } label: {
                Label(copy.measuringGuideLink, systemImage: "ruler")
                    .font(DS.Typography.subheadline.weight(.semibold))
                    .frame(minHeight: DS.minimumTapTarget)
            }
            .foregroundStyle(DS.Colors.accent)
        }
        .sheet(isPresented: $showsGuide) {
            MeasuringGuideSheet(copy: copy)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

struct MeasuringGuideSheet: View {
    let copy: OnboardingCopy
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    ForEach(Array(copy.measuringGuideSteps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: DS.Spacing.md) {
                            Text("\(index + 1)")
                                .font(DS.Typography.headline)
                                .foregroundStyle(DS.Colors.onAccent)
                                .frame(width: 30, height: 30)
                                .background(DS.Colors.accent, in: Circle())
                                .accessibilityHidden(true)
                            Text(step)
                                .font(DS.Typography.body)
                                .foregroundStyle(DS.Colors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Step \(index + 1). \(step)")
                    }
                    InfoBanner(copy.measuringGuideTip, title: "Tip")
                }
                .padding(DS.Spacing.page)
            }
            .dsPageBackground()
            .navigationTitle(copy.measuringGuideTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

struct ParentHeightsStepView: View {
    @Bindable var controller: OnboardingController
    let onCancel: (() -> Void)?

    var body: some View {
        let copy = controller.copy
        StepScaffold(controller: controller, title: copy.parentHeightsTitle, subtitle: copy.parentHeightsSubtitle, onCancel: onCancel) {
            ParentHeightCard(label: copy.motherLabel, unknownLabel: copy.parentUnknownLabel,
                             answer: controller.binding(\.mother), unit: controller.binding(\.unit))
            ParentHeightCard(label: copy.fatherLabel, unknownLabel: copy.parentUnknownLabel,
                             answer: controller.binding(\.father), unit: controller.binding(\.unit))
            Text(copy.parentHeightsFooter)
                .font(DS.Typography.footnote)
                .foregroundStyle(DS.Colors.textSecondary)
        }
    }
}

/// One parent: enter a height (with measured/estimate) or choose "don't know".
struct ParentHeightCard: View {
    let label: String
    let unknownLabel: String
    @Binding var answer: ParentHeightAnswer?
    @Binding var unit: HeightUnit

    private var isUnknown: Bool { answer == .unknown }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HeightInput(label: label, centimeters: Binding(
                    get: { answer?.heightCm },
                    set: { cm in
                        if let cm { answer = .known(heightCm: cm, source: source) } else if !isUnknown { answer = nil }
                    }
                ), unit: $unit, range: HeightValidation.parentRange, showsSlider: false)
                .disabled(isUnknown)
                .opacity(isUnknown ? 0.45 : 1)

                if let cm = answer?.heightCm, HeightValidation.validate(cm, range: HeightValidation.parentRange) != .valid {
                    InfoBanner("Check this height and its unit.", tone: .caution)
                }

                if answer?.heightCm != nil {
                    SegmentedChoice("How accurate?", options: ParentHeightSource.allCases, selection: Binding(
                        get: { source },
                        set: { newSource in if let cm = answer?.heightCm { answer = .known(heightCm: cm, source: newSource) } }
                    )) { $0.title }
                }

                Toggle(unknownLabel, isOn: Binding(
                    get: { isUnknown },
                    set: { answer = $0 ? .unknown : nil }
                ))
                .font(DS.Typography.subheadline)
                .tint(DS.Colors.accent)
            }
        }
    }

    private var source: ParentHeightSource {
        if case .known(_, let source)? = answer { return source }
        return .estimated
    }
}

struct HistoryQuestionStepView: View {
    @Bindable var controller: OnboardingController
    let onCancel: (() -> Void)?

    var body: some View {
        let copy = controller.copy
        StepScaffold(controller: controller, title: copy.historyQuestionTitle, subtitle: copy.historyQuestionSubtitle, onCancel: onCancel) {
            VStack(spacing: DS.Spacing.sm) {
                SelectionCard(title: copy.historyYes, systemImage: "clock.arrow.circlepath", isSelected: controller.draft.hasHistory == true) {
                    controller.update { $0.hasHistory = true }
                }
                SelectionCard(title: copy.historyNo, systemImage: "arrow.right", isSelected: controller.draft.hasHistory == false) {
                    controller.update { $0.hasHistory = false }
                }
            }
            Text(copy.historyQuestionFooter)
                .font(DS.Typography.footnote)
                .foregroundStyle(DS.Colors.textSecondary)
        }
    }
}

struct HistoryEntryStepView: View {
    @Bindable var controller: OnboardingController
    let onCancel: (() -> Void)?

    private var latestAllowedDate: Date {
        let current = controller.flow.currentMeasurementDate(for: controller.draft)
        return controller.calendar.date(byAdding: .day, value: -1, to: current) ?? current
    }

    private var earliestAllowedDate: Date {
        controller.draft.birthDate ?? controller.calendar.date(byAdding: .year, value: -20, to: controller.today)!
    }

    var body: some View {
        let copy = controller.copy
        let issues = controller.historyIssues
        StepScaffold(controller: controller, title: copy.historyEntryTitle, subtitle: copy.historyEntrySubtitle, onCancel: onCancel) {
            ForEach(controller.draft.history) { entry in
                HistoryRowCard(
                    entry: binding(for: entry.id),
                    unit: controller.binding(\.unit),
                    dateRange: earliestAllowedDate...max(earliestAllowedDate, latestAllowedDate),
                    issues: (issues[entry.id] ?? []).map(copy.historyIssueMessage),
                    warning: HistoryValidation.warnings(for: entry, currentHeightCm: controller.draft.currentHeightCm).isEmpty ? nil : copy.historyTallerWarning,
                    onRemove: { controller.update { $0.history.removeAll { $0.id == entry.id } } }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if controller.draft.history.count < HistoryValidation.maximumEntries {
                AppButton(copy.historyAddAction, systemImage: "plus", kind: .secondary) {
                    controller.update { $0.history.append(HistoryEntryDraft()) }
                }
            }
        }
        .onAppear {
            if controller.draft.history.isEmpty { controller.update { $0.history.append(HistoryEntryDraft()) } }
        }
    }

    private func binding(for id: UUID) -> Binding<HistoryEntryDraft> {
        Binding(
            get: { controller.draft.history.first { $0.id == id } ?? HistoryEntryDraft(id: id) },
            set: { updated in
                controller.update { draft in
                    if let index = draft.history.firstIndex(where: { $0.id == id }) { draft.history[index] = updated }
                }
            }
        )
    }
}

struct HistoryRowCard: View {
    @Binding var entry: HistoryEntryDraft
    @Binding var unit: HeightUnit
    let dateRange: ClosedRange<Date>
    let issues: [String]
    let warning: String?
    let onRemove: () -> Void

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    if entry.date == nil {
                        Button("Add date") { entry.date = dateRange.upperBound }
                            .font(DS.Typography.body.weight(.semibold))
                            .frame(minHeight: DS.minimumTapTarget)
                    } else {
                        DateInput("Date", date: $entry.date, in: dateRange, defaultDate: dateRange.upperBound)
                    }
                    Spacer()
                    Button(role: .destructive, action: onRemove) {
                        Image(systemName: "trash")
                            .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
                    }
                    .foregroundStyle(DS.Colors.textSecondary)
                    .accessibilityLabel("Remove this measurement")
                }
                HeightInput(centimeters: $entry.heightCm, unit: $unit, showsSlider: false)
                ForEach(issues, id: \.self) { InfoBanner($0, tone: .caution) }
                if let warning { InfoBanner(warning, tone: .info) }
            }
        }
    }
}

struct GrowthChangeStepView: View {
    @Bindable var controller: OnboardingController
    let onCancel: (() -> Void)?

    var body: some View {
        let copy = controller.copy
        StepScaffold(controller: controller, title: copy.growthChangeTitle, subtitle: copy.growthChangeSubtitle, onCancel: onCancel) {
            VStack(spacing: DS.Spacing.sm) {
                ForEach(RecentGrowthChange.allCases, id: \.self) { option in
                    SelectionCard(title: option.title, systemImage: option.symbol, isSelected: controller.draft.recentGrowthChange == option) {
                        controller.update { $0.recentGrowthChange = option }
                    }
                }
            }
        }
    }
}
#endif
