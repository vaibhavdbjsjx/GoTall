#if os(iOS)
import SwiftUI
import GrowthCore
import GrowthEngine
import DesignSystem

struct GoalsStepView: View {
    @Bindable var controller: OnboardingController
    let onCancel: (() -> Void)?

    var body: some View {
        let copy = controller.copy
        StepScaffold(controller: controller, title: copy.goalsTitle, subtitle: copy.goalsSubtitle, onCancel: onCancel) {
            GoalsEditor(goals: controller.binding(\.goals), available: copy.availableGoals)
        }
    }
}

struct IntentStepView: View {
    @Bindable var controller: OnboardingController
    let onCancel: (() -> Void)?

    var body: some View {
        let copy = controller.copy
        StepScaffold(controller: controller, title: copy.intentTitle, subtitle: copy.intentSubtitle, onCancel: onCancel) {
            VStack(spacing: DS.Spacing.sm) {
                ForEach(UserIntent.allCases, id: \.self) { intent in
                    SelectionCard(title: intent.title, systemImage: intent.symbol, isSelected: controller.draft.intent == intent) {
                        controller.update { $0.intent = intent }
                    }
                }
            }
        }
    }
}

struct ConcernSupportStepView: View {
    @Bindable var controller: OnboardingController
    let onCancel: (() -> Void)?

    var body: some View {
        let copy = controller.copy
        StepScaffold(controller: controller, title: copy.concernTitle, primaryTitle: copy.concernAction, onCancel: onCancel) {
            AppCard {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    ForEach(copy.concernBody, id: \.self) { paragraph in
                        Text(paragraph)
                            .font(DS.Typography.body)
                            .foregroundStyle(DS.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            InfoBanner(copy.medicalNote, title: "Not medical advice")
        }
    }
}

/// Short, honest transition: it only says the profile is being put together (which is true: it's being saved).
struct BuildingProfileStepView: View {
    @Bindable var controller: OnboardingController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn = false

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            ZStack {
                Circle().stroke(DS.Colors.accentSoft, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: drawn ? 1 : 0.05)
                    .stroke(DS.Colors.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                BrandMark(size: 56)
            }
            .frame(width: 120, height: 120)
            Text(controller.copy.buildingTitle)
                .font(DS.Typography.title)
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(DS.Spacing.page)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dsPageBackground()
        .accessibilityElement(children: .combine)
        .task {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.8)) { drawn = true }
            try? await Task.sleep(nanoseconds: reduceMotion ? 300_000_000 : 900_000_000)
            controller.goNext()
        }
    }
}

struct SummaryStepView: View {
    @Bindable var controller: OnboardingController
    let onCancel: (() -> Void)?

    var body: some View {
        let copy = controller.copy
        let preview = try? ProfileBuilder(flow: controller.flow).build(from: controller.draft)
        StepScaffold(
            controller: controller,
            title: copy.summaryTitle,
            subtitle: copy.summarySubtitle,
            primaryTitle: copy.finishAction,
            primaryEnabled: preview != nil,
            onCancel: onCancel,
            primaryAction: { controller.finish() }
        ) {
            if let preview {
                GrowthOverviewCard(profile: preview, analysis: GrowthAnalyzer(now: controller.today, calendar: controller.calendar).analyze(preview))
                    .appearEffect()
                let summary = ProfileSummary(profile: preview, now: controller.today, calendar: controller.calendar)
                ForEach(Array(summary.sections.enumerated()), id: \.element.id) { index, section in
                    SummarySectionCard(section: section) {
                        if let step = section.editStep { controller.edit(step) }
                    }
                    .appearEffect(delay: min(0.15, Double(index) * 0.02))
                }
                Text("Only what's shown here is saved, on this device.")
                    .font(DS.Typography.footnote)
                    .foregroundStyle(DS.Colors.textSecondary)
            } else {
                InfoBanner("A required answer is missing. Go back to complete it.", tone: .caution)
            }
            if controller.finishError != nil {
                InfoBanner("We couldn't save the profile. Please check the answers above and try again.", tone: .caution)
            }
        }
    }
}

/// Top of the summary: the first real results (current percentile and, where eligible, the estimate range).
struct GrowthOverviewCard: View {
    let profile: GrowthProfile
    let analysis: GrowthAnalysis

    var body: some View {
        let unit = profile.unitPreference
        AppCard(padding: DS.Spacing.lg) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(alignment: .top) {
                    if let latest = analysis.latest {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current height").font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                            Text(HeightFormatter.string(centimeters: latest.heightCm, unit: unit))
                                .font(DS.Typography.metricLarge)
                                .foregroundStyle(DS.Colors.textPrimary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    Spacer()
                    if let p = analysis.currentPercentile {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Percentile").font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                            Text(PercentileFormatter.ordinal(p.percentile)).font(DS.Typography.metric).foregroundStyle(DS.Colors.accent)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                Divider()
                if case .scenario(let s) = analysis.adultHeight {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(GrowthCopy.estimateTitle).font(DS.Typography.subheadline.weight(.semibold)).foregroundStyle(DS.Colors.textPrimary)
                            Spacer()
                            Badge(GrowthCopy.uncertaintyLabel(s.uncertainty))
                        }
                        Text(GrowthCopy.range(s.lowCm, s.highCm, unit: unit)).font(DS.Typography.metric).foregroundStyle(DS.Colors.textPrimary)
                            .accessibilityLabel("Estimated adult height, \(GrowthCopy.accessibleRange(s.lowCm, s.highCm, unit: unit))")
                        Text(GrowthCopy.estimateDisclaimer).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                    }
                } else if let message = GrowthCopy.outcomeMessage(analysis.adultHeight, isChild: profile.subject == .child) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(message.title).font(DS.Typography.subheadline.weight(.semibold)).foregroundStyle(DS.Colors.textPrimary)
                        Text(message.body).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if analysis.latestIsEstimate {
                    Text(GrowthCopy.estimatedNotice).font(DS.Typography.footnote).foregroundStyle(DS.Colors.caution)
                }
            }
        }
    }
}

struct SummarySectionCard: View {
    let section: ProfileSummary.Section
    let onEdit: (() -> Void)?

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    Label(section.title, systemImage: section.symbol)
                        .font(DS.Typography.headline)
                        .foregroundStyle(DS.Colors.textPrimary)
                    Spacer()
                    if let onEdit, section.editStep != nil {
                        Button("Edit", action: onEdit)
                            .font(DS.Typography.subheadline.weight(.semibold))
                            .foregroundStyle(DS.Colors.accent)
                            .frame(minWidth: DS.minimumTapTarget, minHeight: DS.minimumTapTarget)
                            .accessibilityLabel("Edit \(section.title)")
                    }
                }
                ForEach(section.rows) { row in
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.label).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                        Spacer(minLength: DS.Spacing.md)
                        Text(row.value)
                            .font(DS.Typography.subheadline.weight(.medium))
                            .foregroundStyle(row.value == "Not provided" ? DS.Colors.textTertiary : DS.Colors.textPrimary)
                            .multilineTextAlignment(.trailing)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
#endif
