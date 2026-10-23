#if os(iOS)
import SwiftUI
import UserNotifications
import GrowthCore
import GrowthEngine
import DesignSystem

// MARK: - Routine row

/// A routine in a list: focus, title, length, and a play affordance (or a Pro badge).
struct RoutineRow: View {
    let routine: Routine
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(LinearGradient(colors: [DS.Colors.accentSoft, DS.Colors.surfaceSecondary], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: symbol).font(.system(.title3, design: .rounded).weight(.semibold)).foregroundStyle(DS.Colors.accent)
                }
                .frame(width: 52, height: 52)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(routine.focus.title.uppercased()).font(DS.Typography.eyebrow).foregroundStyle(DS.Colors.textTertiary)
                    Text(routine.title).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                    Text("\(routine.minutes) min · \(routine.moves.count) moves").font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                }
                Spacer(minLength: 0)
                if isLocked {
                    PremiumBadge()
                } else {
                    Image(systemName: "play.circle.fill").font(.system(size: 30)).foregroundStyle(DS.Colors.accent)
                        .accessibilityHidden(true)
                }
            }
            .padding(DS.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsSurface()
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(isLocked ? "Part of Gromax Pro" : "Starts the routine")
    }

    private var symbol: String {
        switch routine.focus {
        case .posture: return "figure.stand"
        case .mobility: return "figure.flexibility"
        case .core: return "figure.core.training"
        case .morning: return "sunrise"
        case .evening: return "moon.stars"
        case .desk: return "laptopcomputer"
        }
    }
}

// MARK: - Bedtime planner

/// Works back from wake-up time to a bedtime, with an optional nightly wind-down reminder.
struct BedtimePlannerView: View {
    let repository: AppRepository
    let profile: GrowthProfile
    @Environment(\.dismiss) private var dismiss
    @State private var settings: BedtimeSettings
    @State private var reminderDenied = false

    init(repository: AppRepository, profile: GrowthProfile) {
        self.repository = repository
        self.profile = profile
        _settings = State(initialValue: profile.wellness.bedtime ?? BedtimeSettings())
    }

    private var ageYears: Int { profile.age(on: Date(), calendar: .current)?.years ?? 14 }

    var body: some View {
        let recommendation = BedtimePlanner.recommendation(ageYears: ageYears)
        let plan = BedtimePlanner.plan(settings: settings, ageYears: ageYears)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    VStack(spacing: DS.Spacing.xs) {
                        Text("BEDTIME").font(DS.Typography.eyebrow).foregroundStyle(DS.Colors.accent)
                        Text(BedtimePlanner.timeText(plan.bedtimeMinutes))
                            .font(DS.Typography.heroNumber).foregroundStyle(DS.Colors.textPrimary)
                            .contentTransition(.numericText())
                        Text("for \(BedtimePlanner.durationText(plan.targetSleepMinutes)) of sleep, waking at \(BedtimePlanner.timeText(plan.wakeMinutes))")
                            .font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.lg)
                    .heroSurface()

                    AppCard {
                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            DatePicker("Wake-up time", selection: minutesBinding(\.wakeMinutes), displayedComponents: .hourAndMinute)
                                .font(DS.Typography.headline)
                            Divider()
                            Stepper(value: sleepBinding(default: recommendation.targetMinutes), in: 6 * 60...12 * 60, step: 15) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Sleep goal").font(DS.Typography.headline)
                                    Text(BedtimePlanner.durationText(plan.targetSleepMinutes)).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                                }
                            }
                            Divider()
                            Stepper(value: $settings.windDownMinutes, in: 15...60, step: 15) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Wind-down").font(DS.Typography.headline)
                                    Text("Screens off from \(BedtimePlanner.timeText(plan.windDownStartMinutes))").font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                                }
                            }
                            Divider()
                            Toggle(isOn: $settings.remindersOn) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Wind-down reminder").font(DS.Typography.headline)
                                    Text("A gentle nudge each evening.").font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                                }
                            }
                            .tint(DS.Colors.accent)
                            if reminderDenied {
                                InfoBanner("Notifications are off for Gromax. Turn them on in Settings to get the reminder.", tone: .caution)
                            }
                        }
                    }
                    QuietNote(title: "Recommended at \(ageYears)", message: "\(Int(recommendation.rangeHours.lowerBound))–\(Int(recommendation.rangeHours.upperBound)) hours a night. Source: \(recommendation.source).", symbol: "moon.stars")
                    AppButton("Save") { save(plan: plan) }
                }
                .padding(DS.Spacing.page)
            }
            .dsPageBackground()
            .navigationTitle("Bedtime planner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func save(plan: BedtimePlanner.Plan) {
        let settings = settings
        repository.updateWellness(for: profile.id, at: Date()) { $0.bedtime = settings }
        Task {
            if settings.remindersOn {
                let granted = await BedtimeReminder.schedule(plan: plan, profile: profile)
                if !granted { reminderDenied = true; return }
            } else {
                BedtimeReminder.cancel(profileID: profile.id)
            }
            dismiss()
        }
    }

    private func minutesBinding(_ key: WritableKeyPath<BedtimeSettings, Int>) -> Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: settings[keyPath: key] / 60, minute: settings[keyPath: key] % 60, second: 0, of: Date()) ?? Date() },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                settings[keyPath: key] = (c.hour ?? 7) * 60 + (c.minute ?? 0)
            }
        )
    }

    private func sleepBinding(default value: Int) -> Binding<Int> {
        Binding(get: { settings.targetSleepMinutes ?? value }, set: { settings.targetSleepMinutes = $0 })
    }
}

/// The nightly wind-down reminder: one repeating local notification per profile. Separate from the planner-managed
/// reminders (different identifier prefix), so re-planning those never removes it.
enum BedtimeReminder {
    static func id(_ profileID: UUID) -> String { "stature.bedtime." + profileID.uuidString }

    /// Returns false if notification permission is denied.
    static func schedule(plan: BedtimePlanner.Plan, profile: GrowthProfile) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return false }
        } else if settings.authorizationStatus == .denied {
            return false
        }
        let content = UNMutableNotificationContent()
        content.title = "Time to wind down"
        let who = profile.subject == .child ? "\(profile.nickname ?? "Your child")'s" : "Your"
        content.body = "\(who) bedtime is \(BedtimePlanner.timeText(plan.bedtimeMinutes)). Screens away, lights low."
        content.sound = .default
        var components = DateComponents()
        components.hour = plan.windDownStartMinutes / 60
        components.minute = plan.windDownStartMinutes % 60
        let request = UNNotificationRequest(identifier: id(profile.id), content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true))
        try? await center.add(request)
        return true
    }

    static func cancel(profileID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id(profileID)])
    }
}

// MARK: - Food variety

/// Tap the food groups eaten today. Three or more counts as a good day. No calories, no portions.
struct FoodVarietyView: View {
    let repository: AppRepository
    let profileID: UUID
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let profile = repository.profiles.first { $0.id == profileID }
        let today = Date()
        let groups = profile.map { MealLog.groups(on: today, in: $0, calendar: .current) } ?? []
        let goodDays = profile.map { MealLog.goodDaysThisWeek(in: $0, today: today, calendar: .current) } ?? 0
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    HStack(spacing: DS.Spacing.lg) {
                        ProgressRing(progress: Double(min(groups.count, MealLog.goodDayGroups)) / Double(MealLog.goodDayGroups), lineWidth: 9) {
                            Text("\(groups.count)").font(DS.Typography.metric).foregroundStyle(DS.Colors.textPrimary)
                                .contentTransition(.numericText())
                        }
                        .frame(width: 84, height: 84)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(groups.count >= MealLog.goodDayGroups ? "Good variety today" : "Aim for three groups")
                                .font(DS.Typography.title).foregroundStyle(DS.Colors.textPrimary)
                            Text("\(goodDays) of the last 7 days had good variety.").font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                        }
                    }
                    AppCard(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(FoodGroup.allCases.enumerated()), id: \.element) { index, group in
                                CheckInRow(title: group.title, subtitle: group.examples, symbol: group.symbol, isDone: groups.contains(group)) {
                                    withAnimation(Motion.standard) {
                                        repository.toggleFoodGroup(group, on: today, for: profileID, calendar: .current)
                                    }
                                }
                                if index < FoodGroup.allCases.count - 1 { Divider().padding(.leading, 72) }
                            }
                        }
                    }
                    QuietNote(title: "Why food groups, not calories", message: "Growing bodies need variety: protein, calcium and vitamin D for bones, and fruit and vegetables for everything else. Counting calories isn't needed and can make eating stressful.", symbol: "leaf")
                }
                .padding(DS.Spacing.page)
            }
            .dsPageBackground()
            .navigationTitle("Food variety")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

// MARK: - Puberty check

struct PubertyCheckView: View {
    let repository: AppRepository
    let profile: GrowthProfile
    @Environment(\.dismiss) private var dismiss
    @State private var answers: [String: String] = [:]
    @State private var index = 0
    @State private var finished: PubertyStage?

    var body: some View {
        let questions = PubertyCheck.questions(for: profile.chartSex, subject: profile.subject)
        NavigationStack {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                if let stage = finished {
                    resultView(stage)
                } else {
                    ProgressView(value: Double(index), total: Double(questions.count)).tint(DS.Colors.accent)
                    let question = questions[index]
                    Text(question.text).font(DS.Typography.question).foregroundStyle(DS.Colors.textPrimary)
                        .id(question.id)
                        .transition(.opacity)
                    VStack(spacing: DS.Spacing.sm) {
                        ForEach(question.options) { option in
                            SelectionCard(title: option.title, isSelected: answers[question.id] == option.id) {
                                answers[question.id] = option.id
                                withAnimation(Motion.page) {
                                    if index + 1 < questions.count {
                                        index += 1
                                    } else {
                                        complete()
                                    }
                                }
                            }
                        }
                    }
                    Spacer()
                    Text(PubertyCheck.disclaimer).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textTertiary)
                }
            }
            .padding(DS.Spacing.page)
            .dsPageBackground()
            .navigationTitle("Puberty check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(finished == nil ? "Cancel" : "Done") { dismiss() } }
                if finished == nil && index > 0 {
                    ToolbarItem(placement: .topBarTrailing) { Button("Back") { withAnimation(Motion.page) { index -= 1 } } }
                }
            }
        }
    }

    private func complete() {
        let stage = PubertyCheck.stage(answers: answers, sex: profile.chartSex)
        let record = PubertyCheckRecord(date: Date(), answers: answers, stage: stage)
        repository.updateWellness(for: profile.id, at: Date()) { $0.puberty = record }
        finished = stage
    }

    private func resultView(_ stage: PubertyStage) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text("LIKELY STAGE").font(DS.Typography.eyebrow).foregroundStyle(DS.Colors.accent)
            Text(PubertyCheck.title(stage)).font(DS.Typography.display).foregroundStyle(DS.Colors.textPrimary)
            Text(PubertyCheck.explanation(stage, sex: profile.chartSex)).font(DS.Typography.body).foregroundStyle(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            QuietNote(title: "Keep measuring", message: "Growth speed from your measurements is the clearest sign of where growth is. Measure every three months.", symbol: "ruler")
            Spacer()
            Text(PubertyCheck.disclaimer).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textTertiary)
            AppButton("Done") { dismiss() }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
}

// MARK: - Outgrow forecast

struct OutgrowForecastView: View {
    let forecast: OutgrowForecast
    let profile: GrowthProfile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("Now: about size \(forecast.currentSize)").font(DS.Typography.title).foregroundStyle(DS.Colors.textPrimary)
                        if let change = forecast.nextSizeChange {
                            Text("Likely to need size \(change.clothingSize) in about \(change.months) months.")
                                .font(DS.Typography.body).foregroundStyle(DS.Colors.textSecondary)
                        } else {
                            Text("The same size should fit for the next year.").font(DS.Typography.body).foregroundStyle(DS.Colors.textSecondary)
                        }
                    }
                    AppCard(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(forecast.points.enumerated()), id: \.element.id) { index, point in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("In \(point.months) months").font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                                        Text(point.date.formatted(.dateTime.month(.wide).year())).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("+\(GrowthCopy.speed(point.gainCm, unit: profile.unitPreference))").font(DS.Typography.metricSmall).foregroundStyle(DS.Colors.accent)
                                        Text("size \(point.clothingSize)").font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                                    }
                                }
                                .padding(DS.Spacing.md)
                                if index < forecast.points.count - 1 { Divider().padding(.leading, DS.Spacing.md) }
                            }
                        }
                    }
                    if let months = forecast.shoeCheckMonths {
                        QuietNote(title: "Shoes", message: "Feet grow in spurts too. At this age, check shoe fit about every \(months) months: there should be a thumb's width of space at the toe.", symbol: "shoeprints.fill")
                    }
                    QuietNote(title: "How this works", message: "Gromax follows the current percentile line on the CDC growth chart, which is how most children grow over a few months. Sizes are approximate US children's sizes; brands vary.", symbol: "info.circle")
                }
                .padding(DS.Spacing.page)
            }
            .dsPageBackground()
            .navigationTitle("Outgrow forecast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

// MARK: - Doctor visit kit

struct DoctorVisitKitView: View {
    let kit: DoctorVisitKit
    let title: String
    let onOpenReport: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    Text("Questions worth asking, built from \(title.lowercased() == "your" ? "your" : "this profile's") own measurements.")
                        .font(DS.Typography.body).foregroundStyle(DS.Colors.textSecondary)
                    AppCard {
                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            ForEach(Array(kit.questions.enumerated()), id: \.offset) { index, question in
                                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                                    Text("\(index + 1)").font(DS.Typography.headline).foregroundStyle(DS.Colors.accent).frame(width: 20)
                                    Text(question).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    SectionHeader("Bring with you")
                    AppCard {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            ForEach(kit.bring, id: \.self) { item in
                                Label(item, systemImage: "checkmark.circle").font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                            }
                        }
                    }
                    ShareLink(item: kit.plainText(title: "Doctor visit: \(title)")) {
                        Label("Share or save to Notes", systemImage: "square.and.arrow.up")
                            .font(DS.Typography.headline).frame(maxWidth: .infinity).frame(minHeight: 50)
                            .foregroundStyle(DS.Colors.accent)
                            .background(DS.Colors.accentSoft, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                    }
                    AppButton("Open the growth report (PDF)", systemImage: "doc.richtext") {
                        dismiss()
                        onOpenReport()
                    }
                }
                .padding(DS.Spacing.page)
            }
            .dsPageBackground()
            .navigationTitle("Doctor visit kit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
#endif
