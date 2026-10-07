import XCTest
@testable import GrowthCore

final class DashboardTests: XCTestCase {
    func builder(_ now: Date = T.today) -> DashboardBuilder {
        DashboardBuilder(now: now, calendar: T.calendar, locale: T.locale)
    }

    func profile(birth: Date = T.date(2011, 3, 15), measurements: [HeightMeasurement]? = nil, subject: ProfileSubject = .myself) -> GrowthProfile {
        GrowthProfile(subject: subject, nickname: subject == .child ? "Maya" : nil, birthDate: birth, chartSex: .female, unitPreference: .centimeters,
                      measurements: measurements ?? [HeightMeasurement(date: T.date(2026, 10, 1), heightCm: 158.2, method: .home, origin: .onboardingCurrent)],
                      createdAt: T.today, updatedAt: T.today)
    }

    func testSingleMeasurementShowsHintNotFakeTrend() {
        let state = builder().build(for: profile())
        XCTAssertEqual(state.height?.value, "158.2 cm")
        XCTAssertEqual(state.height?.measuredWhen, "6 days ago")
        XCTAssertNil(state.change)
        XCTAssertNotNil(state.changeHint)
        XCTAssertEqual(state.insight.title, "The trend starts with your next measurement")
    }

    func testChangeIsComputedFromRealMeasurementsOnly() {
        let p = profile(measurements: [
            HeightMeasurement(date: T.date(2025, 3, 1), heightCm: 154.0, method: .professional, origin: .onboardingHistory),
            HeightMeasurement(date: T.date(2026, 10, 1), heightCm: 158.2, method: .home, origin: .onboardingCurrent)
        ])
        let state = builder().build(for: p)
        XCTAssertEqual(state.change?.value, "+4.2 cm")
        XCTAssertEqual(state.change?.since, "since Mar 2025")
    }

    func testNoPredictionNumberIsEverShown() {
        for birth in [T.date(2023, 1, 1), T.date(2011, 3, 15), T.date(2007, 1, 1), T.date(1990, 1, 1)] {
            let state = builder().build(for: profile(birth: birth))
            XCTAssertFalse(state.estimate.message.contains(" cm"), "Estimate card must not contain a height")
            XCTAssertFalse(state.percentileMessage.contains("%"))
        }
    }

    func testEstimateAvailabilityByAge() {
        let estimator = PendingGrowthEstimator()
        func availability(_ birth: Date) -> EstimateAvailability {
            estimator.availability(for: profile(birth: birth), on: T.today, calendar: T.calendar)
        }
        XCTAssertEqual(availability(T.date(2023, 6, 1)), .chartOnlyAge)   // 3
        XCTAssertEqual(availability(T.date(2020, 6, 1)), .engineNotAvailable) // 6
        XCTAssertEqual(availability(T.date(2007, 6, 1)), .nearAdult)       // 19
        XCTAssertEqual(availability(T.date(1990, 6, 1)), .adult)
    }

    func testChildTitleUsesNickname() {
        XCTAssertEqual(builder().build(for: profile(birth: T.date(2017, 1, 1), subject: .child)).title, "Maya’s growth")
    }

    func testHabitBaselinesComeFromOnboardingOrStayEmpty() {
        var p = profile()
        var state = builder().build(for: p)
        XCTAssertTrue(state.habits.allSatisfy { $0.value == nil })
        p.sleep = SleepBaseline(bedtime: TimeOfDay(hour: 22, minute: 15), wakeTime: TimeOfDay(hour: 7, minute: 0))
        p.activity = ActivityBaseline(level: .active, frequency: .threeToFour)
        state = builder().build(for: p)
        XCTAssertEqual(state.habits.first { $0.kind == .sleep }?.value, "About 8 h 45 min on weeknights")
        XCTAssertEqual(state.habits.first { $0.kind == .activity }?.value, "Active · 3–4 sessions a week")
    }

    func testGoalsReorderQuickActions() {
        var p = profile()
        XCTAssertEqual(builder().build(for: p).quickActions, [.measure, .viewGrowth, .habits])
        p.goals = [.sleepConsistency]
        XCTAssertEqual(builder().build(for: p).quickActions, [.measure, .habits, .viewGrowth])
    }

    func testConcernedIntentPrioritisesRecordKeepingInsight() {
        var p = profile()
        p.intent = .concerned
        XCTAssertEqual(builder().build(for: p).insight.symbol, "stethoscope")
    }

    func testRelativeDates() {
        XCTAssertEqual(DisplayFormat.relative(T.today, to: T.today, calendar: T.calendar), "Today")
        XCTAssertEqual(DisplayFormat.relative(T.date(2026, 10, 6), to: T.today, calendar: T.calendar), "Yesterday")
        XCTAssertEqual(DisplayFormat.relative(T.date(2026, 9, 16), to: T.today, calendar: T.calendar), "3 weeks ago")
        XCTAssertEqual(DisplayFormat.relative(T.date(2026, 6, 1), to: T.today, calendar: T.calendar), "4 months ago")
        XCTAssertEqual(DisplayFormat.relative(T.date(2024, 6, 1), to: T.today, calendar: T.calendar), "Over a year ago")
    }

    func testSummaryShowsOnlyRelevantSections() throws {
        let adult = try ProfileBuilder(flow: T.flow()).build(from: T.completeDraft(birth: T.date(1990, 1, 1)))
        let ids = ProfileSummary(profile: adult, now: T.today, calendar: T.calendar, locale: T.locale).sections.map(\.id)
        XCTAssertFalse(ids.contains("family"))
        XCTAssertFalse(ids.contains("change"))
        let teen = try ProfileBuilder(flow: T.flow()).build(from: T.completeDraft())
        let teenIDs = ProfileSummary(profile: teen, now: T.today, calendar: T.calendar, locale: T.locale).sections.map(\.id)
        XCTAssertTrue(teenIDs.contains("family"))
    }
}

final class CopyTests: XCTestCase {
    private func allCopy(for draft: OnboardingDraft, band: AgeBand?) -> [String] {
        let copy = OnboardingCopy(draft: draft, ageBand: band)
        var strings = [
            copy.welcomeTitle, copy.welcomeSubtitle, copy.medicalNote, copy.subjectTitle, copy.nicknameTitle, copy.nicknameSubtitle,
            copy.birthDateTitle, copy.birthDateSubtitle, copy.chartSexTitle, copy.chartSexSubtitle, copy.chartSexHelp,
            copy.heightTitle, copy.heightSubtitle, copy.measuringGuideTip, copy.parentHeightsTitle, copy.parentHeightsSubtitle,
            copy.parentHeightsFooter, copy.historyQuestionTitle, copy.historyQuestionSubtitle, copy.historyEntrySubtitle,
            copy.growthChangeTitle, copy.growthChangeSubtitle, copy.sleepTitle, copy.sleepSubtitle, copy.activityTitle,
            copy.activitySubtitle, copy.nutritionTitle, copy.nutritionSubtitle, copy.goalsTitle, copy.goalsSubtitle,
            copy.intentTitle, copy.intentSubtitle, copy.concernTitle, copy.buildingTitle, copy.summaryTitle,
            copy.estimatePlaceholder, copy.percentilePlaceholder
        ]
        strings += copy.welcomePoints.flatMap { [$0.title, $0.detail] }
        strings += copy.privacyPoints.flatMap { [$0.title, $0.detail] }
        strings += copy.measuringGuideSteps + copy.concernBody
        return strings
    }

    func testNoBannedPhrasesAnywhere() {
        let variants: [(ProfileSubject, AgeBand)] = [(.myself, .teen), (.child, .child), (.myself, .adult), (.myself, .youngAdult)]
        for (subject, band) in variants {
            var draft = T.draft(subject: subject)
            draft.nickname = "Maya"
            for text in allCopy(for: draft, band: band) {
                XCTAssertEqual(CopyGuard.violations(in: text), [], "\"\(text)\"")
            }
        }
        let optionTitles: [String] = Goal.allCases.map(\.title) + UserIntent.allCases.map(\.title) + EatingChallenge.allCases.map(\.title)
        for title in optionTitles { XCTAssertEqual(CopyGuard.violations(in: title), [], title) }
    }

    func testCopyGuardCatchesViolations() {
        XCTAssertEqual(CopyGuard.violations(in: "Unlock your true height!"), ["unlock your", "true height"])
        XCTAssertEqual(CopyGuard.violations(in: "95% accurate"), ["% accurate"])
    }

    func testParentLanguageUsesChildName() {
        var draft = T.draft(subject: .child)
        draft.nickname = "Maya"
        let copy = OnboardingCopy(draft: draft, ageBand: .child)
        XCTAssertEqual(copy.heightTitle, "How tall is Maya now?")
        XCTAssertEqual(copy.birthDateTitle, "When was Maya born?")
        XCTAssertEqual(copy.parentHeightsTitle, "How tall are Maya’s biological parents?")
        XCTAssertEqual(copy.summaryTitle, "Maya’s growth profile")
    }

    func testParentLanguageWithoutNickname() {
        let copy = OnboardingCopy(draft: T.draft(subject: .child), ageBand: .child)
        XCTAssertEqual(copy.heightTitle, "How tall is your child now?")
        XCTAssertEqual(copy.summaryTitle, "Your child’s growth profile")
    }

    func testSelfLanguage() {
        let copy = OnboardingCopy(draft: T.draft(subject: .myself), ageBand: .teen)
        XCTAssertEqual(copy.heightTitle, "How tall are you now?")
        XCTAssertEqual(copy.sleepTitle, "What does a typical school night look like?")
        XCTAssertEqual(OnboardingCopy(draft: T.draft(subject: .myself), ageBand: .adult).sleepTitle, "What does a typical weeknight look like?")
    }

    func testAdultsDontSeeGrowthOnlyGoals() {
        let goals = OnboardingCopy(draft: T.draft(subject: .myself), ageBand: .adult).availableGoals
        XCTAssertFalse(goals.contains(.understandPercentile))
        XCTAssertTrue(goals.contains(.sleepConsistency))
    }

    func testBrandNameIsConfigurableAndNotCompetitor() {
        XCTAssertFalse(BrandConfig.current.displayName.lowercased().contains("tall"))
        XCTAssertEqual(CopyGuard.violations(in: BrandConfig.current.tagline), [])
    }
}
