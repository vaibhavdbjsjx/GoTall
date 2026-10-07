#if DEBUG
import Foundation

/// Synthetic profiles for simulator screenshots and previews. DEBUG builds only; never shipped.
/// Selected with the launch argument `-demoScenario <name>`.
public enum DemoScenario: String, CaseIterable, Sendable {
    case teen, parent, starter, adult, concern, onboarding, onboardingSummary

    /// 28 days of synthetic check-ins: full days except `missed` offsets (none) and `partial` offsets (one habit).
    func habitHistory(now: Date, calendar: Calendar, missed: Set<Int>, partial: Set<Int>) -> [HabitDay] {
        (0..<28).compactMap { offset -> HabitDay? in
            guard !missed.contains(offset), offset > 0 else { return nil } // today left open for the check-in UI
            let date = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -offset, to: now)!)
            return HabitDay(date: date, completed: partial.contains(offset) ? [.sleep] : [.sleep, .activity, .meals])
        }.sorted { $0.date < $1.date }
    }

    public func snapshot(now: Date = Date(), calendar: Calendar = .current) -> AppSnapshot {
        func ago(years: Int = 0, months: Int = 0, days: Int = 0) -> Date {
            calendar.startOfDay(for: calendar.date(byAdding: DateComponents(year: -years, month: -months, day: -days), to: now)!)
        }
        func m(_ monthsAgo: Int, _ cm: Double, _ method: MeasurementMethod = .home) -> HeightMeasurement {
            HeightMeasurement(date: ago(months: monthsAgo), heightCm: cm, method: method, origin: .manual)
        }
        let ack = PrivacyAcknowledgement(acknowledgedAt: now)

        switch self {
        case .teen:
            let p = GrowthProfile(
                subject: .myself, birthDate: ago(years: 14, months: 3), chartSex: .female, unitPreference: .centimeters,
                measurements: [m(26, 148.0, .professional), m(20, 151.1), m(14, 154.6), m(8, 157.4, .professional), m(1, 159.3)],
                parentHeights: ParentHeights(mother: .known(heightCm: 165, source: .measured), father: .known(heightCm: 178, source: .estimated)),
                recentGrowthChange: .slower,
                sleep: SleepBaseline(bedtime: TimeOfDay(hour: 22, minute: 30), wakeTime: TimeOfDay(hour: 7, minute: 0), consistency: .laterOnWeekends),
                activity: ActivityBaseline(level: .active, frequency: .threeToFour, preferred: [.teamSports, .running]),
                nutrition: NutritionBaseline(mealRegularity: .mostDays, pattern: .noRestrictions, challenges: [.skipBreakfast], hydration: .mixed),
                goals: [.trackHeight, .understandPercentile], intent: .understanding,
                habitLog: habitHistory(now: now, calendar: calendar, missed: [3, 9, 17, 18, 24], partial: [1, 6, 12]),
                createdAt: now, updatedAt: now)
            return AppSnapshot(profiles: [p], activeProfileID: p.id, privacyAcknowledgement: ack)
        case .parent:
            let ava = GrowthProfile(
                subject: .child, nickname: "Ava", birthDate: ago(years: 9, months: 2), chartSex: .female, unitPreference: .feetInches,
                measurements: [m(18, 124.5, .professional), m(11, 128.0), m(2, 132.6)],
                parentHeights: ParentHeights(mother: .known(heightCm: 160, source: .measured), father: .known(heightCm: 183, source: .measured)),
                goals: [.longTermRecord, .seeChanges], intent: .tracking, createdAt: now, updatedAt: now)
            let leo = GrowthProfile(
                subject: .child, nickname: "Leo", birthDate: ago(years: 6, months: 5), chartSex: .male, unitPreference: .feetInches,
                measurements: [m(0, 117.0, .estimate)], goals: [.trackHeight], createdAt: now, updatedAt: now)
            return AppSnapshot(profiles: [ava, leo], activeProfileID: ava.id, privacyAcknowledgement: ack)
        case .starter:
            let p = GrowthProfile(
                subject: .myself, birthDate: ago(years: 15, months: 1), chartSex: .male, unitPreference: .centimeters,
                measurements: [m(7, 166.0, .estimate)], goals: [.trackHeight], intent: .curious, createdAt: now, updatedAt: now)
            return AppSnapshot(profiles: [p], activeProfileID: p.id, privacyAcknowledgement: ack)
        case .adult:
            let p = GrowthProfile(
                subject: .myself, birthDate: ago(years: 29), chartSex: .male, unitPreference: .centimeters,
                measurements: [m(14, 178.2), m(1, 178.0)],
                sleep: SleepBaseline(bedtime: TimeOfDay(hour: 23, minute: 30), wakeTime: TimeOfDay(hour: 7, minute: 0), consistency: .veryDifferent),
                goals: [.sleepConsistency, .healthierRoutines], intent: .healthyHabits, createdAt: now, updatedAt: now)
            return AppSnapshot(profiles: [p], activeProfileID: p.id, privacyAcknowledgement: ack)
        case .concern:
            let p = GrowthProfile(
                subject: .child, nickname: "Sam", birthDate: ago(years: 10, months: 4), chartSex: .male, unitPreference: .centimeters,
                measurements: [m(15, 124.0, .professional), m(1, 127.5, .professional)],
                parentHeights: ParentHeights(mother: .known(heightCm: 158, source: .measured), father: .unknown),
                intent: .concerned, createdAt: now, updatedAt: now)
            return AppSnapshot(profiles: [p], activeProfileID: p.id, privacyAcknowledgement: ack)
        case .onboardingSummary:
            var draft = OnboardingDraft(mode: .firstRun, startedAt: now)
            draft.privacyAcknowledged = true
            draft.subject = .child
            draft.nickname = "Maya"
            draft.birthDate = ago(years: 11, months: 4)
            draft.chartSex = .female
            draft.currentHeightCm = 146.2
            draft.currentHeightMethod = .professional
            draft.currentHeightDate = calendar.startOfDay(for: now)
            draft.mother = .known(heightCm: 166, source: .measured)
            draft.father = .known(heightCm: 181, source: .estimated)
            draft.hasHistory = false
            draft.recentGrowthChange = .faster
            draft.sleep = SleepBaseline(bedtime: TimeOfDay(hour: 21, minute: 0), wakeTime: TimeOfDay(hour: 7, minute: 0), consistency: .similarEveryDay)
            draft.goals = [.longTermRecord, .understandPercentile]
            draft.intent = .tracking
            draft.currentStep = .summary
            return AppSnapshot(onboardingDraft: draft, privacyAcknowledgement: ack)
        case .onboarding:
            var draft = OnboardingDraft(mode: .firstRun, startedAt: now)
            draft.privacyAcknowledged = true
            draft.subject = .myself
            draft.birthDate = ago(years: 14, months: 3)
            draft.chartSex = .female
            draft.currentHeightCm = 159.3
            draft.currentHeightDate = calendar.startOfDay(for: now)
            draft.currentStep = .currentHeight
            return AppSnapshot(onboardingDraft: draft, privacyAcknowledgement: ack)
        }
    }
}
#endif
