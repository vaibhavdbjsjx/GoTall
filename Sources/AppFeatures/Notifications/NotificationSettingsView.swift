#if os(iOS)
import SwiftUI
import UIKit
import GrowthCore
import DesignSystem

/// Reminder settings. Each category has its own toggle, schedule and description. Turning one on is the
/// moment iOS asks for permission (never at launch). Shows the next scheduled reminder as iOS reports it.
struct NotificationSettingsView: View {
    let repository: AppRepository
    @Environment(NotificationCoordinator.self) private var notifications
    @Environment(\.openURL) private var openURL
    @State private var busy: NotificationCategory?
    @State private var needsSettings = false

    var body: some View {
        let prefs = repository.snapshot.notificationPreferences
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                if notifications.authorization == .denied || needsSettings {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        InfoBanner("Notifications are turned off for this app in iOS Settings, so reminders can't be delivered.", title: "Notifications are off", tone: .caution)
                        AppButton("Open Settings", systemImage: "gear", kind: .secondary) {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                        }
                    }
                    .accessibilityIdentifier("notifications.denied")
                }

                category(.measurementReminder, title: "Measurement reminders", symbol: "ruler",
                         description: "Remind me when it's time to measure again.", isOn: prefs.measurementReminders) {
                    measurementSchedule(prefs)
                }
                category(.dailyCheckIn, title: "Daily check-in", symbol: "checklist",
                         description: "Remind me to complete my selected habits.", isOn: prefs.dailyCheckIn) {
                    dailySchedule(prefs)
                }
                category(.weeklySummary, title: "Weekly summary", symbol: "calendar",
                         description: "Give me a short review of my week.", isOn: prefs.weeklySummary) {
                    weeklySchedule()
                }

                QuietNote(title: "Calm by design", message: "Reminders never mention streaks or height gain, and height is never requested daily. Everything is scheduled on this iPhone; nothing is sent to a server.", symbol: "leaf")
            }
            .padding(.horizontal, DS.Spacing.page)
            .padding(.vertical, DS.Spacing.md)
        }
        .dsPageBackground()
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await notifications.sync(repository.snapshot)
        }
    }

    @ViewBuilder
    private func category<Schedule: View>(_ category: NotificationCategory, title: String, symbol: String, description: String,
                                          isOn: Bool, @ViewBuilder schedule: () -> Schedule) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Toggle(isOn: Binding(get: { isOn }, set: { newValue in toggle(category, newValue) })) {
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    Image(systemName: symbol)
                        .foregroundStyle(DS.Colors.accent)
                        .frame(width: 28, height: 28)
                        .background(DS.Colors.accentSoft, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .accessibilityHidden(true)
                        .hiddenAtAccessibilitySizes()
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                        Text(description).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .tint(DS.Colors.accent)
            .disabled(busy != nil)
            .accessibilityIdentifier("notifications.toggle.\(category.rawValue)")
            if isOn {
                Divider()
                schedule()
                    .transition(.opacity)
            }
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsSurface()
        .animation(Motion.standard, value: isOn)
    }

    private func toggle(_ category: NotificationCategory, _ enabled: Bool) {
        busy = category
        Task {
            let result = await notifications.setCategory(category, enabled: enabled, repository: repository)
            needsSettings = result == .needsSystemSettings
            busy = nil
        }
    }

    // MARK: Schedules

    @ViewBuilder
    private func measurementSchedule(_ prefs: NotificationPreferences) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Picker(selection: Binding(get: { prefs.measurementInterval }, set: { newValue in
                var p = repository.snapshot.notificationPreferences
                p.measurementInterval = newValue
                repository.setNotificationPreferences(p)
                Task { await notifications.sync(repository.snapshot) }
            })) {
                Text("Recommended").tag(MeasurementReminderInterval.recommended)
                ForEach(MeasurementReminderInterval.customChoices, id: \.self) { months in
                    Text(months == 1 ? "Every month" : (months == 12 ? "Every year" : "Every \(months) months")).tag(MeasurementReminderInterval.months(months))
                }
            } label: {
                Text("How often").font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textPrimary)
            }
            .tint(DS.Colors.accent)
            .accessibilityIdentifier("notifications.interval")
            Text(prefs.measurementInterval == .recommended
                 ? "Recommended: every 3 months while growing (ages 2–17), every 6 months at 18–20. Measuring more often mostly shows measuring differences."
                 : "Counted from the latest measurement. A new measurement moves the reminder automatically.")
                .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(repository.profiles) { profile in
                nextLine(title: repository.profiles.count > 1 ? "Your next measurement reminder · \(profile.displayLabel)" : "Your next measurement reminder",
                         date: notifications.nextMeasurementReminder(for: profile.id),
                         empty: "No reminder needed for adults on the recommended interval.")
            }
        }
    }

    @ViewBuilder
    private func dailySchedule(_ prefs: NotificationPreferences) -> some View {
        let preset = CheckInTimePreset.preset(for: prefs.dailyCheckInTime)
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SegmentedChoice("Check-in time", options: CheckInTimePreset.allCases, selection: Binding(get: { preset }, set: { newValue in
                guard let time = newValue.time else {
                    // Custom keeps the current time and reveals the time picker.
                    var p = repository.snapshot.notificationPreferences
                    if CheckInTimePreset.preset(for: p.dailyCheckInTime) != .custom {
                        p.dailyCheckInTime = TimeOfDay(hour: p.dailyCheckInTime.hour, minute: 30)
                        setPreferences(p)
                    }
                    return
                }
                var p = repository.snapshot.notificationPreferences
                p.dailyCheckInTime = time
                setPreferences(p)
            })) { $0.title }
            if preset == .custom {
                DatePicker("Time", selection: Binding(
                    get: { Calendar.current.date(bySettingHour: prefs.dailyCheckInTime.hour, minute: prefs.dailyCheckInTime.minute, second: 0, of: Date()) ?? Date() },
                    set: { date in
                        var p = repository.snapshot.notificationPreferences
                        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                        p.dailyCheckInTime = TimeOfDay(hour: c.hour ?? 19, minute: c.minute ?? 0)
                        setPreferences(p)
                    }), displayedComponents: .hourAndMinute)
                    .font(DS.Typography.subheadline)
            }
            nextLine(title: "Next check-in reminder", date: notifications.nextScheduled(.dailyCheckIn)?.fireDate, empty: "Scheduling…")
                .accessibilityIdentifier("notifications.next.daily")
            Text("Skipped on days you've already checked in. After a week without opening the app, reminders stop until you're back.")
                .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func weeklySchedule() -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if let next = notifications.nextScheduled(.weeklySummary)?.fireDate {
                nextLine(title: "Next weekly summary", date: next, empty: "")
            } else {
                Text("Sent on Sundays at 6 PM, only after a week with real activity (3 or more check-in days, or a measurement). This week doesn't have enough yet, so nothing is scheduled.")
                    .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func setPreferences(_ p: NotificationPreferences) {
        repository.setNotificationPreferences(p)
        Task { await notifications.sync(repository.snapshot) }
    }

    private func nextLine(title: String, date: Date?, empty: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
            if let date {
                Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()))
                    .font(DS.Typography.subheadline.weight(.semibold)).foregroundStyle(DS.Colors.textPrimary)
            } else {
                Text(empty).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
            }
        }
        .padding(DS.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.accentSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// The week in review (opened from the weekly notification or Habits). Every number comes from saved data.
struct WeeklySummaryView: View {
    let repository: AppRepository
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if let profile = repository.activeProfile {
                    let summary = WeeklySummary(profile: profile, now: Date(), calendar: .current)
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Text("Last 7 days").font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                            Text(summary.headline).font(DS.Typography.title).foregroundStyle(DS.Colors.textPrimary)
                                .accessibilityIdentifier("weekly.headline")
                            WeekDots(days: summary.days.map { day in
                                let formatter = DateFormatter()
                                formatter.setLocalizedDateFormatFromTemplate("EEEEE")
                                return WeekDots.Day(id: day.date, letter: formatter.string(from: day.date), fraction: day.fraction, isToday: day.isToday)
                            })
                        }
                        .padding(DS.Spacing.lg)
                        .heroSurface()

                        AppCard(padding: 0) {
                            VStack(spacing: 0) {
                                ForEach(summary.habitCounts) { count in
                                    HStack {
                                        Label(count.kind.title, systemImage: count.kind.symbol).foregroundStyle(DS.Colors.textPrimary)
                                        Spacer()
                                        Text("\(count.days) of 7 days").font(DS.Typography.subheadline.monospacedDigit()).foregroundStyle(DS.Colors.textSecondary)
                                    }
                                    .padding(DS.Spacing.md)
                                    .accessibilityElement(children: .combine)
                                    Divider()
                                }
                                HStack {
                                    Label("Measurements this week", systemImage: "ruler").foregroundStyle(DS.Colors.textPrimary)
                                    Spacer()
                                    Text("\(summary.measurementsThisWeek)").font(DS.Typography.subheadline.monospacedDigit()).foregroundStyle(DS.Colors.textSecondary)
                                }
                                .padding(DS.Spacing.md)
                                .accessibilityElement(children: .combine)
                            }
                        }
                        if let next = summary.nextMeasurementDate {
                            QuietNote(title: "Next measurement", message: "Around \(DisplayFormat.day(next, calendar: .current)). Every few months is plenty.", symbol: "calendar")
                        }
                        QuietNote(title: "About these numbers", message: "A check-in day is a day with at least one habit noted. Current rhythm: \(summary.rhythm) day\(summary.rhythm == 1 ? "" : "s") (one missed day a week is forgiven). Habits never change any height number.", symbol: "info.circle")
                    }
                    .padding(DS.Spacing.page)
                }
            }
            .dsPageBackground()
            .navigationTitle("Your week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
#endif
