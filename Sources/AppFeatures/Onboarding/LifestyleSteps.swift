#if os(iOS)
import SwiftUI
import GrowthCore
import DesignSystem

struct SleepStepView: View {
    @Bindable var controller: OnboardingController
    let onCancel: (() -> Void)?

    private var defaults: (bed: TimeOfDay, wake: TimeOfDay) {
        switch controller.ageBand {
        case .child?: return (TimeOfDay(hour: 20, minute: 30), TimeOfDay(hour: 7, minute: 0))
        case .teen?: return (TimeOfDay(hour: 22, minute: 30), TimeOfDay(hour: 7, minute: 0))
        default: return (TimeOfDay(hour: 23, minute: 0), TimeOfDay(hour: 7, minute: 0))
        }
    }

    var body: some View {
        let copy = controller.copy
        let sleep = controller.draft.sleep
        StepScaffold(controller: controller, title: copy.sleepTitle, subtitle: copy.sleepSubtitle, onCancel: onCancel) {
            AppCard {
                VStack(spacing: DS.Spacing.xs) {
                    optionalTime(label: copy.bedtimeLabel, keyPath: \.bedtime, defaultTime: defaults.bed, addTitle: "Add bedtime")
                    Divider()
                    optionalTime(label: copy.wakeLabel, keyPath: \.wakeTime, defaultTime: defaults.wake, addTitle: "Add wake time")
                    if let minutes = sleep.typicalDurationMinutes {
                        Divider()
                        HStack {
                            Text("Typical sleep").font(DS.Typography.body).foregroundStyle(DS.Colors.textSecondary)
                            Spacer()
                            Text(DisplayFormat.duration(minutes: minutes))
                                .font(DS.Typography.metricSmall)
                                .foregroundStyle(DS.Colors.textPrimary)
                                .contentTransition(.numericText())
                        }
                        .frame(minHeight: DS.minimumTapTarget)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                FieldLabel(copy.sleepConsistencyLabel)
                FlowLayout {
                    ForEach(SleepConsistency.allCases, id: \.self) { option in
                        SelectableChip(title: option.title, isSelected: sleep.consistency == option) {
                            controller.update { $0.sleep.consistency = $0.sleep.consistency == option ? nil : option }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func optionalTime(label: String, keyPath: WritableKeyPath<SleepBaseline, TimeOfDay?>, defaultTime: TimeOfDay, addTitle: String) -> some View {
        if controller.draft.sleep[keyPath: keyPath] == nil {
            HStack {
                Text(label).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
                Spacer()
                Button(addTitle) { controller.update { $0.sleep[keyPath: keyPath] = defaultTime } }
                    .font(DS.Typography.body.weight(.semibold))
                    .foregroundStyle(DS.Colors.accent)
            }
            .frame(minHeight: DS.minimumTapTarget)
        } else {
            TimeInput(label, time: controller.binding((\OnboardingDraft.sleep).appending(path: keyPath)), defaultTime: defaultTime)
        }
    }
}

struct ActivityStepView: View {
    @Bindable var controller: OnboardingController
    let onCancel: (() -> Void)?

    var body: some View {
        let copy = controller.copy
        let activity = controller.draft.activity
        StepScaffold(controller: controller, title: copy.activityTitle, subtitle: copy.activitySubtitle, onCancel: onCancel) {
            VStack(spacing: DS.Spacing.sm) {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    SelectionCard(title: level.title, detail: level.detail, systemImage: level.symbol, isSelected: activity.level == level) {
                        controller.update { $0.activity.level = level }
                    }
                }
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                FieldLabel(copy.activityFrequencyLabel)
                FlowLayout {
                    ForEach(ExerciseFrequency.allCases, id: \.self) { option in
                        SelectableChip(title: option.title, isSelected: activity.frequency == option) {
                            controller.update { $0.activity.frequency = $0.activity.frequency == option ? nil : option }
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                FieldLabel(copy.activityPreferredLabel)
                FlowLayout {
                    ForEach(ActivityType.allCases, id: \.self) { type in
                        SelectableChip(title: type.title, systemImage: type.symbol, isSelected: activity.preferred.contains(type)) {
                            controller.update { draft in
                                if let index = draft.activity.preferred.firstIndex(of: type) {
                                    draft.activity.preferred.remove(at: index)
                                } else {
                                    draft.activity.preferred.append(type)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct NutritionStepView: View {
    @Bindable var controller: OnboardingController
    let onCancel: (() -> Void)?

    var body: some View {
        let copy = controller.copy
        let nutrition = controller.draft.nutrition
        StepScaffold(controller: controller, title: copy.nutritionTitle, subtitle: copy.nutritionSubtitle, onCancel: onCancel) {
            chipGroup(copy.mealRegularityLabel, options: MealRegularity.allCases, selected: nutrition.mealRegularity) { option in
                controller.update { $0.nutrition.mealRegularity = $0.nutrition.mealRegularity == option ? nil : option }
            }
            chipGroup(copy.dietaryPatternLabel, options: DietaryPattern.allCases, selected: nutrition.pattern) { option in
                controller.update { $0.nutrition.pattern = $0.nutrition.pattern == option ? nil : option }
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                FieldLabel(copy.eatingChallengesLabel)
                FlowLayout {
                    ForEach(EatingChallenge.allCases, id: \.self) { challenge in
                        SelectableChip(title: challenge.title, isSelected: nutrition.challenges.contains(challenge)) {
                            controller.update { draft in
                                if let index = draft.nutrition.challenges.firstIndex(of: challenge) {
                                    draft.nutrition.challenges.remove(at: index)
                                } else {
                                    draft.nutrition.challenges.append(challenge)
                                }
                            }
                        }
                    }
                }
            }
            chipGroup(copy.hydrationLabel, options: HydrationHabit.allCases, selected: nutrition.hydration) { option in
                controller.update { $0.nutrition.hydration = $0.nutrition.hydration == option ? nil : option }
            }
        }
    }

    private func chipGroup<Option: OptionDisplayable & Hashable>(_ label: String, options: [Option], selected: Option?, toggle: @escaping (Option) -> Void) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            FieldLabel(label)
            FlowLayout {
                ForEach(options, id: \.self) { option in
                    SelectableChip(title: option.title, isSelected: selected == option) { toggle(option) }
                }
            }
        }
    }
}
#endif
