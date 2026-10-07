#if os(iOS)
import SwiftUI
import GrowthCore
import DesignSystem

enum EditProfileFocus: Hashable {
    case lifestyle
}

/// Edits a copy of the profile; nothing is saved until Save, and invalid states can't be saved.
struct EditProfileView: View {
    let repository: AppRepository
    let original: GrowthProfile
    let focus: EditProfileFocus?

    @Environment(\.dismiss) private var dismiss
    @State private var draft: GrowthProfile
    @State private var pendingDrops: [DroppedField] = []
    @State private var confirmsDrops = false
    @State private var confirmsDelete = false
    @State private var errorMessage: String?

    init(repository: AppRepository, profile: GrowthProfile, focus: EditProfileFocus?) {
        self.repository = repository
        self.original = profile
        self.focus = focus
        _draft = State(initialValue: profile)
    }

    private var today: Date { Date() }
    private var calendar: Calendar { .current }
    private var band: AgeBand? { draft.age(on: today, calendar: calendar)?.band }
    private var copy: OnboardingCopy {
        var d = OnboardingDraft(mode: .firstRun, startedAt: today)
        d.subject = draft.subject
        d.nickname = draft.nickname
        return OnboardingCopy(draft: d, ageBand: band)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                        basics
                        if band?.isStillGrowing == true || original.parentHeights != ParentHeights() { family }
                        if band != .adult { growthChange }
                        lifestyle.id(EditProfileFocus.lifestyle)
                        goals
                        if let errorMessage { InfoBanner(errorMessage, tone: .caution) }
                        AppButton("Delete this profile", systemImage: "trash", kind: .destructive) { confirmsDelete = true }
                    }
                    .padding(DS.Spacing.page)
                }
                .onAppear { if let focus { proxy.scrollTo(focus, anchor: .top) } }
            }
            .dsPageBackground()
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: attemptSave) }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                }
            }
            .confirmationDialog("Some answers will be removed", isPresented: $confirmsDrops, titleVisibility: .visible) {
                Button("Save and remove them", role: .destructive) { commit(birthChanged: true) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("With this birth date, these aren't used anymore, so they won't be kept: \(pendingDrops.map(\.title).joined(separator: ", ")).")
            }
            .confirmationDialog("Delete this profile?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Delete profile", role: .destructive) {
                    repository.deleteProfile(original.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All of this profile's measurements will be permanently removed from this device.")
            }
        }
    }

    // MARK: Sections

    private var basics: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionHeader("Basics")
            AppCard {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    if draft.subject == .child {
                        TextField("Name or nickname", text: Binding(
                            get: { draft.nickname ?? "" },
                            set: { draft.nickname = $0.isEmpty ? nil : String($0.prefix(30)) }
                        ))
                        .textInputAutocapitalization(.words)
                        .font(DS.Typography.body)
                        .frame(minHeight: DS.minimumTapTarget)
                        Divider()
                    }
                    DatePicker("Date of birth", selection: Binding(
                        get: { draft.birthDate },
                        set: { draft.birthDate = calendar.startOfDay(for: $0) }
                    ), in: (calendar.date(byAdding: .year, value: -100, to: today) ?? today)...today, displayedComponents: .date)
                    .frame(minHeight: DS.minimumTapTarget)
                    if let age = draft.age(on: today, calendar: calendar) {
                        Text("Age \(age.years) years, \(age.months) months").font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        FieldLabel("Growth chart")
                        SegmentedChoice("Growth chart", options: GrowthChartSex.allCases, selection: $draft.chartSex) { $0.title }
                        if draft.chartSex != original.chartSex {
                            Text("Changing the chart recalculates percentiles and estimates.").font(DS.Typography.footnote).foregroundStyle(DS.Colors.caution)
                        }
                    }
                }
            }
        }
    }

    private var family: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionHeader("Family height")
            if band?.isStillGrowing == true {
                ParentHeightCard(label: copy.motherLabel, unknownLabel: copy.parentUnknownLabel, answer: $draft.parentHeights.mother, unit: $draft.unitPreference)
                ParentHeightCard(label: copy.fatherLabel, unknownLabel: copy.parentUnknownLabel, answer: $draft.parentHeights.father, unit: $draft.unitPreference)
            } else {
                InfoBanner("Family height is only used while growing (ages 2–17), so it isn't shown for this age.")
            }
        }
    }

    private var growthChange: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionHeader("Recent growth change")
            FlowLayout {
                ForEach(RecentGrowthChange.allCases, id: \.self) { option in
                    SelectableChip(title: option.title, systemImage: option.symbol, isSelected: draft.recentGrowthChange == option) {
                        draft.recentGrowthChange = draft.recentGrowthChange == option ? nil : option
                    }
                }
            }
            Text("Used only to explain the trend. It doesn't change any estimate.").font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
        }
    }

    private var lifestyle: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            SectionHeader("Sleep")
            SleepBaselineEditor(sleep: $draft.sleep, defaults: SleepDefaults.forBand(band), bedtimeLabel: copy.bedtimeLabel,
                                wakeLabel: copy.wakeLabel, consistencyLabel: copy.sleepConsistencyLabel)
            SectionHeader("Activity")
            ActivityBaselineEditor(activity: $draft.activity, frequencyLabel: copy.activityFrequencyLabel, preferredLabel: copy.activityPreferredLabel)
            SectionHeader("Eating")
            NutritionBaselineEditor(nutrition: $draft.nutrition, copy: copy)
        }
    }

    private var goals: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionHeader("Goals")
            GoalsEditor(goals: $draft.goals, available: copy.availableGoals)
        }
    }

    // MARK: Saving

    private func attemptSave() {
        errorMessage = nil
        guard ProfileEditor.isValidParentAnswer(draft.parentHeights.mother), ProfileEditor.isValidParentAnswer(draft.parentHeights.father) else {
            errorMessage = "Check the parents' heights and their unit."
            return
        }
        let birthChanged = !calendar.isDate(draft.birthDate, inSameDayAs: original.birthDate)
        var reference = original
        reference.parentHeights = draft.parentHeights
        reference.recentGrowthChange = draft.recentGrowthChange
        reference.goals = draft.goals
        switch ProfileEditor.checkBirthDate(draft.birthDate, for: reference, today: today, calendar: calendar) {
        case .invalid(let validation):
            errorMessage = copy.birthDateMessage(validation) ?? "Check the date of birth."
        case .conflictsWithMeasurements(let count):
            errorMessage = "\(count == 1 ? "One measurement is" : "\(count) measurements are") dated before this birth date. Edit or delete \(count == 1 ? "it" : "them") first."
        case .valid(let dropping):
            if birthChanged && !dropping.isEmpty {
                pendingDrops = dropping
                confirmsDrops = true
            } else {
                commit(birthChanged: birthChanged)
            }
        }
    }

    /// Pruning only happens when the birth date itself was edited; natural ageing never deletes answers.
    private func commit(birthChanged: Bool) {
        let updated = birthChanged ? ProfileEditor.applyingBirthDate(draft.birthDate, to: draft, today: today, calendar: calendar) : draft
        repository.updateProfile(updated, at: today)
        dismiss()
    }
}
#endif
