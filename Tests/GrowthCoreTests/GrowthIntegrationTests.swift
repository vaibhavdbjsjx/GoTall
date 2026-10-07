import XCTest
import GrowthEngine
@testable import GrowthCore

final class GrowthAnalysisTests: XCTestCase {
    let analyzer = GrowthAnalyzer(now: T.today, calendar: T.calendar)

    func profile(birth: Date = T.date(2012, 4, 1), sex: GrowthChartSex = .male, measurements: [(Date, Double, MeasurementMethod)]) -> GrowthProfile {
        GrowthProfile(subject: .myself, birthDate: birth, chartSex: sex, unitPreference: .centimeters,
                      measurements: measurements.map { HeightMeasurement(date: $0.0, heightCm: $0.1, method: $0.2, origin: .manual) },
                      createdAt: T.today, updatedAt: T.today)
    }

    func testLifestyleNeverChangesAnyNumber() {
        var p = profile(measurements: [(T.date(2025, 9, 1), 150, .home), (T.date(2026, 9, 1), 157, .professional)])
        p.parentHeights = ParentHeights(mother: .known(heightCm: 165, source: .measured), father: .known(heightCm: 182, source: .measured))
        let baseline = analyzer.analyze(p)
        var changed = p
        changed.sleep = SleepBaseline(bedtime: TimeOfDay(hour: 1, minute: 0), wakeTime: TimeOfDay(hour: 6, minute: 0), consistency: .veryDifferent)
        changed.activity = ActivityBaseline(level: .veryActive, frequency: .fivePlus, preferred: ActivityType.allCases)
        changed.nutrition = NutritionBaseline(mealRegularity: .oftenSkip, pattern: .vegan, challenges: EatingChallenge.allCases, hydration: .mostlySweetDrinks)
        changed.goals = Goal.allCases
        changed.intent = .healthyHabits
        changed.recentGrowthChange = .faster
        let after = analyzer.analyze(changed)
        XCTAssertEqual(baseline.adultHeight, after.adultHeight)
        XCTAssertEqual(baseline.velocity, after.velocity)
        XCTAssertEqual(baseline.family, after.family)
        XCTAssertEqual(baseline.series, after.series)
        XCTAssertEqual(baseline.signposts, after.signposts)
    }

    func testMeasurementMethodMapsToQuality() {
        let a = analyzer.analyze(profile(measurements: [(T.date(2026, 9, 1), 157, .estimate)]))
        XCTAssertTrue(a.latestIsEstimate)
        XCTAssertTrue(a.insights.contains { $0.kind == .estimatedHeight })
    }

    func testFamilyStatus() {
        var p = profile(measurements: [(T.date(2026, 9, 1), 157, .home)])
        XCTAssertEqual(analyzer.analyze(p).family, .missingParentHeights)
        p.parentHeights = ParentHeights(mother: .unknown, father: .known(heightCm: 180, source: .measured))
        XCTAssertEqual(analyzer.analyze(p).family, .missingParentHeights, "Never infer a missing parent")
        p.parentHeights = ParentHeights(mother: .known(heightCm: 160, source: .estimated), father: .known(heightCm: 180, source: .measured))
        guard case .available(let range) = analyzer.analyze(p).family else { return XCTFail() }
        XCTAssertEqual(range.targetCm, 176.5, accuracy: 1e-9)
        XCTAssertTrue(range.usesEstimatedParentHeight)
        let adult = profile(birth: T.date(1990, 1, 1), measurements: [(T.date(2026, 9, 1), 175, .home)])
        XCTAssertEqual(analyzer.analyze(adult).family, .notApplicable)
    }

    func testNextMeasurementConvention() {
        let a = analyzer.analyze(profile(measurements: [(T.date(2026, 9, 1), 157, .home)]))
        XCTAssertEqual(a.nextMeasurement?.suggestedDate, T.calendar.startOfDay(for: T.date(2026, 12, 1)))
        XCTAssertEqual(a.nextMeasurement?.isDue, false)
        let due = analyzer.analyze(profile(measurements: [(T.date(2026, 1, 1), 150, .home)]))
        XCTAssertEqual(due.nextMeasurement?.isDue, true)
        XCTAssertNil(analyzer.analyze(profile(birth: T.date(1990, 1, 1), measurements: [(T.date(2026, 9, 1), 175, .home)])).nextMeasurement)
    }

    func testInsightsAreDataBacked() {
        // Two measurements 3 months apart → needs more time, with the exact date.
        let short = analyzer.analyze(profile(measurements: [(T.date(2026, 6, 1), 155, .home), (T.date(2026, 9, 1), 157, .home)]))
        let needs = try! XCTUnwrap(short.insights.first { $0.kind == .needsMoreTime })
        XCTAssertTrue(needs.body.contains("3 months"), needs.body)
        XCTAssertTrue(needs.body.contains("6 months"), needs.body)
        // Year apart → recent growth with numbers that match the data.
        let year = analyzer.analyze(profile(measurements: [(T.date(2025, 9, 1), 150, .home), (T.date(2026, 9, 1), 157, .home)]))
        let growth = try! XCTUnwrap(year.insights.first { $0.kind == .recentGrowth })
        XCTAssertTrue(growth.body.contains("7.0 cm"), growth.body)
        XCTAssertTrue(growth.body.contains("12 months"), growth.body)
        // Decrease → re-measure, never "shrinking".
        let down = analyzer.analyze(profile(measurements: [(T.date(2025, 9, 1), 157, .home), (T.date(2026, 9, 1), 155, .home)]))
        XCTAssertTrue(down.insights.contains { $0.kind == .measurementDecrease })
    }

    func testSteadyAndShiftInsights() {
        let birth = T.date(2012, 4, 1)
        func height(z: Double, on date: Date) -> Double {
            let age = AgeMath.exactAgeMonths(birthDate: birth, on: date, calendar: T.calendar)
            return PercentileCalculator.height(atZ: z, ageMonths: age, sex: .male, reference: ReferenceRegistry.cdc2000)!
        }
        let dates = [T.date(2025, 3, 1), T.date(2025, 9, 1), T.date(2026, 9, 1)]
        let steady = analyzer.analyze(profile(measurements: dates.map { ($0, height(z: 0.2, on: $0), .home) }))
        XCTAssertTrue(steady.insights.contains { $0.kind == .steadyTrajectory })
        let shift = analyzer.analyze(profile(measurements: [(dates[0], height(z: -0.5, on: dates[0]), .home), (dates[2], height(z: 0.5, on: dates[2]), .home)]))
        XCTAssertTrue(shift.insights.contains { $0.kind == .percentileShift })
    }

    func testAllInsightAndGrowthCopyPassesCopyGuard() {
        let a = analyzer.analyze(profile(measurements: [(T.date(2025, 9, 1), 150, .home), (T.date(2026, 9, 1), 157, .home)]))
        var texts = a.insights.flatMap { [$0.title, $0.body] }
        texts += [GrowthCopy.estimateDisclaimer, GrowthCopy.estimateBasis, GrowthCopy.estimateLimit, GrowthCopy.methodSummary,
                  GrowthCopy.familyExplanation, GrowthCopy.familyFormula, GrowthCopy.familyLimitations, GrowthCopy.familyMissing,
                  GrowthCopy.velocityNeedsMore, GrowthCopy.concernBody, GrowthCopy.estimatedNotice]
        texts += UncertaintyDriver.allCases.map(GrowthCopy.driverText)
        texts += UncertaintyLevel.allCases.map(GrowthCopy.uncertaintyExplanation)
        texts += [GrowthSignpost.belowThirdPercentile, .aboveNinetySeventhPercentile, .crossedLinesDownward(linesCrossed: 2, months: 14)].map(GrowthCopy.signpostText)
        let outcomes: [AdultHeightOutcome] = [.unsupportedAge, .chartOnlyAge, .nearAdult(.unknown), .nearAdult(.growthMostlyComplete), .nearAdult(.stillGrowing(cmPerYear: 2)), .adult, .outsideTypicalRange(percentile: 1), .insufficientData]
        texts += outcomes.compactMap { GrowthCopy.outcomeMessage($0, isChild: false) }.flatMap { [$0.title, $0.body] }
        for text in texts { XCTAssertEqual(CopyGuard.violations(in: text), [], text) }
    }

    func testExplanationSeparatesUsedFromNotUsed() {
        var p = profile(measurements: [(T.date(2026, 9, 1), 157, .home)])
        p.parentHeights = ParentHeights(mother: .known(heightCm: 165, source: .measured), father: .known(heightCm: 182, source: .measured))
        let a = analyzer.analyze(p)
        guard case .scenario(let s) = a.adultHeight else { return XCTFail() }
        let e = GrowthCopy.explanation(for: a, scenario: s, locale: T.locale, calendar: T.calendar)
        XCTAssertTrue(e.used.contains { $0.title == "Current height" })
        XCTAssertTrue(e.used.contains { $0.title == "Growth chart" })
        XCTAssertTrue(e.contextOnly.contains { $0.title == "Family height" })
        XCTAssertTrue(e.notUsed.contains { $0.title.contains("Sleep") })
        XCTAssertFalse(e.used.contains { $0.title.contains("Sleep") || $0.title.contains("Family") })
    }

    func testRangeFormattingHasNoFalsePrecision() {
        XCTAssertEqual(GrowthCopy.range(163.38, 168.04, unit: .centimeters), "163–168 cm")
        XCTAssertEqual(GrowthCopy.range(152.4, 167.6, unit: .feetInches), "5 ft 0 in – 5 ft 6 in")
    }
}

final class MeasurementValidatorTests: XCTestCase {
    let p = GrowthProfile(subject: .myself, birthDate: T.date(2012, 4, 1), chartSex: .male, unitPreference: .centimeters,
                          measurements: [HeightMeasurement(date: T.date(2025, 9, 1), heightCm: 150, method: .home, origin: .manual),
                                         HeightMeasurement(date: T.date(2026, 9, 1), heightCm: 157, method: .home, origin: .manual)],
                          createdAt: T.today, updatedAt: T.today)

    func check(_ height: Double?, _ date: Date, editing: UUID? = nil) -> MeasurementCheck {
        MeasurementValidator.check(heightCm: height, date: date, editingID: editing, profile: p, today: T.today, calendar: T.calendar)
    }

    func testBlockingIssues() {
        XCTAssertEqual(check(nil, T.today).issues, [.heightOutOfRange(.missing)])
        XCTAssertEqual(check(20, T.today).issues, [.heightOutOfRange(.tooShort)])
        XCTAssertEqual(check(158, T.date(2027, 1, 1)).issues, [.dateInFuture])
        XCTAssertEqual(check(100, T.date(2011, 1, 1)).issues, [.dateBeforeBirth])
        XCTAssertTrue(check(158, T.today).canSave)
    }

    func testWarnings() {
        XCTAssertEqual(check(157.5, T.date(2026, 9, 1)).warnings, [.sameDay(count: 1)])
        XCTAssertTrue(check(150, T.today).warnings.contains(.lowerThanPrevious(cm: 7)))
        XCTAssertTrue(check(160, T.date(2026, 1, 1)).warnings.contains(.tallerThanLater(cm: 3)))
        XCTAssertTrue(check(240, T.today).warnings.contains(.unusualForAge))
    }

    func testEditingIgnoresItself() {
        let id = p.measurements[1].id
        XCTAssertEqual(check(157.2, T.date(2026, 9, 1), editing: id).warnings, [])
    }
}

final class ProfileEditingTests: XCTestCase {
    func teen() -> GrowthProfile {
        var p = GrowthProfile(subject: .myself, birthDate: T.date(2011, 3, 15), chartSex: .female, unitPreference: .centimeters,
                              measurements: [HeightMeasurement(date: T.date(2026, 9, 1), heightCm: 158, method: .home, origin: .manual)],
                              createdAt: T.today, updatedAt: T.today)
        p.parentHeights = ParentHeights(mother: .known(heightCm: 165, source: .measured), father: .unknown)
        p.recentGrowthChange = .faster
        p.goals = [.understandPercentile, .sleepConsistency]
        return p
    }

    func testBirthDateToAdultDropsHiddenFields() {
        let result = ProfileEditor.checkBirthDate(T.date(1990, 1, 1), for: teen(), today: T.today, calendar: T.calendar)
        XCTAssertEqual(result, .valid(dropping: [.parentHeights, .recentGrowthChange, .growthOnlyGoals]))
        let updated = ProfileEditor.applyingBirthDate(T.date(1990, 1, 1), to: teen(), today: T.today, calendar: T.calendar)
        XCTAssertEqual(updated.parentHeights, ParentHeights())
        XCTAssertNil(updated.recentGrowthChange)
        XCTAssertEqual(updated.goals, [.sleepConsistency])
    }

    func testBirthDateWithinTeensKeepsEverything() {
        XCTAssertEqual(ProfileEditor.checkBirthDate(T.date(2010, 6, 1), for: teen(), today: T.today, calendar: T.calendar), .valid(dropping: []))
    }

    func testInvalidBirthDates() {
        XCTAssertEqual(ProfileEditor.checkBirthDate(T.date(2027, 1, 1), for: teen(), today: T.today, calendar: T.calendar), .invalid(.inFuture))
        if case .invalid(.needsGuardian) = ProfileEditor.checkBirthDate(T.date(2016, 1, 1), for: teen(), today: T.today, calendar: T.calendar) {} else { XCTFail() }
        XCTAssertEqual(ProfileEditor.checkBirthDate(T.date(2026, 9, 15), for: teen(), today: T.today, calendar: T.calendar), .invalid(.tooYoung))
    }

    func testBirthDateAfterMeasurementsIsRejected() {
        var p = teen()
        p.subject = .child
        p.measurements.append(HeightMeasurement(date: T.date(2016, 1, 1), heightCm: 110, method: .home, origin: .manual))
        XCTAssertEqual(ProfileEditor.checkBirthDate(T.date(2017, 1, 1), for: p, today: T.today, calendar: T.calendar), .conflictsWithMeasurements(count: 1))
    }

    func testParentAnswerValidation() {
        XCTAssertTrue(ProfileEditor.isValidParentAnswer(nil))
        XCTAssertTrue(ProfileEditor.isValidParentAnswer(.unknown))
        XCTAssertTrue(ProfileEditor.isValidParentAnswer(.known(heightCm: 170, source: .measured)))
        XCTAssertFalse(ProfileEditor.isValidParentAnswer(.known(heightCm: 17, source: .measured)))
        XCTAssertTrue(ProfileEditor.canEditParentHeights(teen(), today: T.today, calendar: T.calendar))
    }

    func testUnitChangeDoesNotTouchStoredValues() {
        let p = teen()
        MainActor.assumeIsolated {
            let (repository, _) = T.repository()
            repository.completeOnboarding(with: p)
            repository.setUnitPreference(.feetInches, for: p.id)
            XCTAssertEqual(repository.activeProfile?.unitPreference, .feetInches)
            XCTAssertEqual(repository.activeProfile?.measurements.first?.heightCm, 158)
        }
    }
}

final class RepositoryEditingTests: XCTestCase {
    func testUpdateMeasurementResorts() {
        MainActor.assumeIsolated {
            let (repository, _) = T.repository()
            let p = GrowthProfile(subject: .myself, birthDate: T.date(2012, 1, 1), chartSex: .male, unitPreference: .centimeters,
                                  measurements: [HeightMeasurement(date: T.date(2025, 1, 1), heightCm: 145, method: .home, origin: .manual),
                                                 HeightMeasurement(date: T.date(2026, 1, 1), heightCm: 152, method: .home, origin: .manual)],
                                  createdAt: T.today, updatedAt: T.today)
            repository.completeOnboarding(with: p)
            var edited = p.measurements[0]
            edited.date = T.date(2026, 6, 1)
            edited.heightCm = 155
            repository.updateMeasurement(edited, in: p.id, at: T.today)
            XCTAssertEqual(repository.activeProfile?.measurements.map(\.heightCm), [152, 155])
        }
    }

    func testDeleteProfileSwitchesActiveAndCanEmpty() {
        MainActor.assumeIsolated {
            let (repository, _) = T.repository()
            let a = GrowthProfile(subject: .child, nickname: "A", birthDate: T.date(2015, 1, 1), chartSex: .male, unitPreference: .centimeters,
                                  measurements: [HeightMeasurement(date: T.date(2026, 1, 1), heightCm: 130, method: .home, origin: .manual)], createdAt: T.today, updatedAt: T.today)
            let b = GrowthProfile(subject: .child, nickname: "B", birthDate: T.date(2018, 1, 1), chartSex: .female, unitPreference: .centimeters,
                                  measurements: [HeightMeasurement(date: T.date(2026, 1, 1), heightCm: 115, method: .home, origin: .manual)], createdAt: T.today, updatedAt: T.today)
            repository.completeOnboarding(with: a)
            repository.completeOnboarding(with: b)
            XCTAssertEqual(repository.activeProfile?.nickname, "B")
            repository.deleteProfile(b.id)
            XCTAssertEqual(repository.activeProfile?.nickname, "A")
            repository.deleteProfile(a.id)
            XCTAssertTrue(repository.profiles.isEmpty)
        }
    }

    func testUpdateProfilePersists() {
        MainActor.assumeIsolated {
            let (repository, store) = T.repository()
            var p = GrowthProfile(subject: .myself, birthDate: T.date(2012, 1, 1), chartSex: .male, unitPreference: .centimeters,
                                  measurements: [HeightMeasurement(date: T.date(2026, 1, 1), heightCm: 150, method: .home, origin: .manual)], createdAt: T.today, updatedAt: T.today)
            repository.completeOnboarding(with: p)
            p.goals = [.trackHeight]
            repository.updateProfile(p, at: T.today)
            guard case .loaded(let saved) = store.load() else { return XCTFail() }
            XCTAssertEqual(saved.profiles.first?.goals, [.trackHeight])
        }
    }
}
