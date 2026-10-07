#if os(iOS)
import SwiftUI
import GrowthCore
import DesignSystem

/// Shared editors used by onboarding and by profile editing, so both behave identically.

struct SleepBaselineEditor: View {
    @Binding var sleep: SleepBaseline
    let defaults: (bed: TimeOfDay, wake: TimeOfDay)
    let bedtimeLabel: String
    let wakeLabel: String
    let consistencyLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            AppCard {
                VStack(spacing: DS.Spacing.xs) {
                    optionalTime(label: bedtimeLabel, value: $sleep.bedtime, defaultTime: defaults.bed, addTitle: "Add bedtime")
                    Divider()
                    optionalTime(label: wakeLabel, value: $sleep.wakeTime, defaultTime: defaults.wake, addTitle: "Add wake time")
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
                FieldLabel(consistencyLabel)
                FlowLayout {
                    ForEach(SleepConsistency.allCases, id: \.self) { option in
                        SelectableChip(title: option.title, isSelected: sleep.consistency == option) {
                            sleep.consistency = sleep.consistency == option ? nil : option
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func optionalTime(label: String, value: Binding<TimeOfDay?>, defaultTime: TimeOfDay, addTitle: String) -> some View {
        if value.wrappedValue == nil {
            HStack {
                Text(label).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
                Spacer()
                Button(addTitle) { value.wrappedValue = defaultTime }
                    .font(DS.Typography.body.weight(.semibold))
                    .foregroundStyle(DS.Colors.accent)
            }
            .frame(minHeight: DS.minimumTapTarget)
        } else {
            TimeInput(label, time: value, defaultTime: defaultTime)
        }
    }
}

struct ActivityBaselineEditor: View {
    @Binding var activity: ActivityBaseline
    let frequencyLabel: String
    let preferredLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            VStack(spacing: DS.Spacing.sm) {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    SelectionCard(title: level.title, detail: level.detail, systemImage: level.symbol, isSelected: activity.level == level) {
                        activity.level = level
                    }
                }
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                FieldLabel(frequencyLabel)
                FlowLayout {
                    ForEach(ExerciseFrequency.allCases, id: \.self) { option in
                        SelectableChip(title: option.title, isSelected: activity.frequency == option) {
                            activity.frequency = activity.frequency == option ? nil : option
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                FieldLabel(preferredLabel)
                FlowLayout {
                    ForEach(ActivityType.allCases, id: \.self) { type in
                        SelectableChip(title: type.title, systemImage: type.symbol, isSelected: activity.preferred.contains(type)) {
                            if let index = activity.preferred.firstIndex(of: type) { activity.preferred.remove(at: index) } else { activity.preferred.append(type) }
                        }
                    }
                }
            }
        }
    }
}

struct NutritionBaselineEditor: View {
    @Binding var nutrition: NutritionBaseline
    let copy: OnboardingCopy

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            chipGroup(copy.mealRegularityLabel, options: MealRegularity.allCases, selected: nutrition.mealRegularity) { option in
                nutrition.mealRegularity = nutrition.mealRegularity == option ? nil : option
            }
            chipGroup(copy.dietaryPatternLabel, options: DietaryPattern.allCases, selected: nutrition.pattern) { option in
                nutrition.pattern = nutrition.pattern == option ? nil : option
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                FieldLabel(copy.eatingChallengesLabel)
                FlowLayout {
                    ForEach(EatingChallenge.allCases, id: \.self) { challenge in
                        SelectableChip(title: challenge.title, isSelected: nutrition.challenges.contains(challenge)) {
                            if let index = nutrition.challenges.firstIndex(of: challenge) { nutrition.challenges.remove(at: index) } else { nutrition.challenges.append(challenge) }
                        }
                    }
                }
            }
            chipGroup(copy.hydrationLabel, options: HydrationHabit.allCases, selected: nutrition.hydration) { option in
                nutrition.hydration = nutrition.hydration == option ? nil : option
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

struct GoalsEditor: View {
    @Binding var goals: [Goal]
    let available: [Goal]

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            ForEach(available, id: \.self) { goal in
                MultiSelectCard(title: goal.title, systemImage: goal.symbol, isSelected: goals.contains(goal)) {
                    if let index = goals.firstIndex(of: goal) { goals.remove(at: index) } else { goals.append(goal) }
                }
            }
        }
    }
}

enum SleepDefaults {
    static func forBand(_ band: AgeBand?) -> (bed: TimeOfDay, wake: TimeOfDay) {
        switch band {
        case .child?: return (TimeOfDay(hour: 20, minute: 30), TimeOfDay(hour: 7, minute: 0))
        case .teen?: return (TimeOfDay(hour: 22, minute: 30), TimeOfDay(hour: 7, minute: 0))
        default: return (TimeOfDay(hour: 23, minute: 0), TimeOfDay(hour: 7, minute: 0))
        }
    }
}
#endif
