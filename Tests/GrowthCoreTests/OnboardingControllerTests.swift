import XCTest
@testable import GrowthCore

final class OnboardingControllerTests: XCTestCase {
    @MainActor private static func makeController(_ repository: AppRepository, mode: OnboardingMode = .firstRun) -> OnboardingController {
        OnboardingController(repository: repository, mode: mode, now: { T.today }, calendar: T.calendar)
    }

    /// Answers each step the way a teen setting up their own profile would.
    @MainActor private static func answerCurrentStep(_ c: OnboardingController, subject: ProfileSubject, birth: Date, hasHistory: Bool) {
        switch c.currentStep {
        case .privacy: c.update { $0.privacyAcknowledged = true }
        case .subject: c.update { $0.subject = subject }
        case .nickname: c.update { $0.nickname = "Maya" }
        case .birthDate: c.update { $0.birthDate = birth }
        case .chartSex: c.update { $0.chartSex = .female }
        case .currentHeight: c.update { $0.currentHeightCm = 152.4 }
        case .parentHeights: c.update { $0.mother = .known(heightCm: 165, source: .measured); $0.father = .unknown }
        case .historyQuestion: c.update { $0.hasHistory = hasHistory }
        case .historyEntry: c.update { $0.history = [HistoryEntryDraft(date: T.date(2025, 4, 1), heightCm: 147.0)] }
        case .goals: c.update { $0.goals = [.trackHeight, .sleepConsistency] }
        case .intent: c.update { $0.intent = .tracking }
        default: break
        }
    }

    @MainActor private static func runToSummary(_ c: OnboardingController, subject: ProfileSubject = .myself, birth: Date = T.date(2011, 3, 15), hasHistory: Bool = true) -> [OnboardingStep] {
        var visited: [OnboardingStep] = [c.currentStep]
        var guardCount = 0
        while c.currentStep != .summary && guardCount < 40 {
            Self.answerCurrentStep(c, subject: subject, birth: birth, hasHistory: hasHistory)
            XCTAssertTrue(c.canContinue, "Blocked at \(c.currentStep)")
            c.goNext()
            visited.append(c.currentStep)
            guardCount += 1
        }
        return visited
    }

    func testFullTeenFlowCreatesProfile() {
        MainActor.assumeIsolated {
        let (repository, _) = T.repository()
        let c = Self.makeController(repository)
        XCTAssertEqual(c.currentStep, .welcome)
        let visited = Self.runToSummary(c)
        XCTAssertEqual(visited, [.welcome, .privacy, .subject, .birthDate, .chartSex, .currentHeight, .parentHeights,
                                 .historyQuestion, .historyEntry, .growthChange, .sleep, .activity, .nutrition,
                                 .goals, .intent, .buildingProfile, .summary])
        XCTAssertNotNil(repository.snapshot.privacyAcknowledgement)
        c.finish()
        let profile = try! XCTUnwrap(c.completedProfile)
        XCTAssertEqual(profile.subject, .myself)
        XCTAssertEqual(profile.measurements.count, 2)
        XCTAssertEqual(profile.latestMeasurement?.heightCm, 152.4)
        XCTAssertEqual(profile.measurements.first?.origin, .onboardingHistory)
        XCTAssertEqual(profile.primaryGoal, .trackHeight)
        XCTAssertNil(repository.snapshot.onboardingDraft, "Draft cleared after completion")
        XCTAssertEqual(repository.activeProfile?.id, profile.id)
        }
    }

    func testParentFlowCreatesChildProfileWithoutParentIdentity() {
        MainActor.assumeIsolated {
        let (repository, _) = T.repository()
        let c = Self.makeController(repository)
        let visited = Self.runToSummary(c, subject: .child, birth: T.date(2017, 6, 2), hasHistory: false)
        XCTAssertTrue(visited.contains(.nickname))
        XCTAssertFalse(visited.contains(.historyEntry))
        c.finish()
        let profile = try! XCTUnwrap(c.completedProfile)
        XCTAssertEqual(profile.subject, .child)
        XCTAssertEqual(profile.nickname, "Maya")
        XCTAssertEqual(profile.measurements.count, 1)
        XCTAssertEqual(repository.profiles.count, 1, "Only the child profile exists; nothing is stored about the parent")
        }
    }

    func testAdultFlowSkipsGrowthChapterQuestions() {
        MainActor.assumeIsolated {
        let (repository, _) = T.repository()
        let c = Self.makeController(repository)
        let visited = Self.runToSummary(c, birth: T.date(1990, 2, 2))
        XCTAssertFalse(visited.contains(.parentHeights))
        XCTAssertFalse(visited.contains(.historyQuestion))
        XCTAssertFalse(visited.contains(.growthChange))
        }
    }

    func testBackNavigationRetainsAnswers() {
        MainActor.assumeIsolated {
        let (repository, _) = T.repository()
        let c = Self.makeController(repository)
        c.goNext() // privacy
        c.update { $0.privacyAcknowledged = true }
        c.goNext() // subject
        c.update { $0.subject = .myself }
        c.goNext() // birthDate
        XCTAssertEqual(c.currentStep, .birthDate)
        c.goBack()
        XCTAssertEqual(c.currentStep, .subject)
        XCTAssertEqual(c.direction, .backward)
        XCTAssertEqual(c.draft.subject, .myself, "Going back must not lose answers")
        c.goBack(); c.goBack()
        XCTAssertEqual(c.currentStep, .welcome)
        XCTAssertFalse(c.canGoBack)
        }
    }

    func testContinueIsIgnoredWhenStepIsIncomplete() {
        MainActor.assumeIsolated {
        let (repository, _) = T.repository()
        let c = Self.makeController(repository)
        c.goNext() // privacy
        c.goNext() // blocked: not acknowledged
        XCTAssertEqual(c.currentStep, .privacy)
        }
    }

    func testBackFromAfterBuildingScreenSkipsTransientStep() {
        MainActor.assumeIsolated {
        let (repository, _) = T.repository()
        let c = Self.makeController(repository)
        _ = Self.runToSummary(c)
        c.goBack()
        XCTAssertEqual(c.currentStep, .intent)
        }
    }

    func testSkipClearsPartialAnswers() {
        MainActor.assumeIsolated {
        let (repository, _) = T.repository()
        let c = Self.makeController(repository)
        _ = Self.runToSummary(c)
        c.edit(.parentHeights)
        c.update { $0.mother = .known(heightCm: 170, source: .measured) }
        c.skip()
        XCTAssertNil(c.draft.mother)
        XCTAssertNil(c.draft.father)
        XCTAssertEqual(c.currentStep, .summary, "Skipping while editing returns to the summary")
        }
    }

    func testEditFromSummaryReturnsToSummary() {
        MainActor.assumeIsolated {
        let (repository, _) = T.repository()
        let c = Self.makeController(repository)
        _ = Self.runToSummary(c)
        c.edit(.sleep)
        XCTAssertEqual(c.currentStep, .sleep)
        c.update { $0.sleep.bedtime = TimeOfDay(hour: 22, minute: 0) }
        c.goNext()
        XCTAssertEqual(c.currentStep, .summary)
        XCTAssertFalse(c.draft.editingFromSummary)
        }
    }

    func testEditBackButtonReturnsToSummaryWithoutLosingEdits() {
        MainActor.assumeIsolated {
        let (repository, _) = T.repository()
        let c = Self.makeController(repository)
        _ = Self.runToSummary(c)
        c.edit(.activity)
        c.update { $0.activity.level = .active }
        c.goBack()
        XCTAssertEqual(c.currentStep, .summary)
        XCTAssertEqual(c.draft.activity.level, .active)
        }
    }

    func testCreatingAControllerHasNoSideEffects() {
        MainActor.assumeIsolated {
        // SwiftUI may construct views (and therefore controllers) repeatedly; that must never write.
        let (repository, store) = T.repository()
        _ = Self.makeController(repository)
        _ = Self.makeController(repository)
        XCTAssertEqual(store.saveCount, 0)
        XCTAssertNil(repository.snapshot.onboardingDraft)
        }
    }

    func testEveryAnswerIsPersistedImmediately() {
        MainActor.assumeIsolated {
        let (repository, store) = T.repository()
        let c = Self.makeController(repository)
        let before = store.saveCount
        c.update { $0.subject = .child }
        XCTAssertEqual(store.saveCount, before + 1)
        guard case .loaded(let saved) = store.load() else { return XCTFail() }
        XCTAssertEqual(saved.onboardingDraft?.subject, .child)
        }
    }

    func testResumeAfterTerminationContinuesWhereLeftOff() throws {
        try MainActor.assumeIsolated {
        let fileStore = try T.makeFileStore()
        do {
            let repository = AppRepository(store: fileStore)
            let c = Self.makeController(repository)
            c.goNext()
            c.update { $0.privacyAcknowledged = true }
            c.goNext()
            c.update { $0.subject = .child }
            c.goNext()
            c.update { $0.nickname = "Leo" }
            c.goNext()
            c.update { $0.birthDate = T.date(2016, 8, 20) }
            XCTAssertEqual(c.currentStep, .birthDate)
        }
        // Simulated termination: everything in memory is gone; only the file remains.
        let relaunched = AppRepository(store: fileStore)
        let resumed = Self.makeController(relaunched)
        XCTAssertTrue(resumed.isResumed)
        XCTAssertEqual(resumed.currentStep, .birthDate)
        XCTAssertEqual(resumed.draft.nickname, "Leo")
        XCTAssertEqual(resumed.draft.subject, .child)
        XCTAssertEqual(resumed.draft.birthDate, T.date(2016, 8, 20))
        }
    }

    func testResumeOnTransientStepMovesToSummary() {
        MainActor.assumeIsolated {
        var draft = T.completeDraft()
        draft.currentStep = .buildingProfile
        let (repository, _) = T.repository(AppSnapshot(onboardingDraft: draft))
        let c = Self.makeController(repository)
        XCTAssertEqual(c.currentStep, .summary)
        }
    }

    func testResumeOnNowHiddenStepMovesForward() {
        MainActor.assumeIsolated {
        var draft = T.completeDraft(birth: T.date(1990, 1, 1)) // adult: historyEntry hidden
        draft.currentStep = .historyEntry
        let (repository, _) = T.repository(AppSnapshot(onboardingDraft: draft))
        let c = Self.makeController(repository)
        XCTAssertEqual(c.currentStep, .sleep)
        }
    }

    func testIncompleteOnboardingCannotFinish() {
        MainActor.assumeIsolated {
        let (repository, _) = T.repository()
        let c = Self.makeController(repository)
        c.update { $0.subject = .myself }
        c.finish()
        XCTAssertNil(c.completedProfile)
        XCTAssertNotNil(c.finishError)
        XCTAssertTrue(repository.profiles.isEmpty)
        XCTAssertNotNil(repository.snapshot.onboardingDraft, "Draft kept for later")
        }
    }

    func testUnderThirteenSelfSetupHandsOverToGuardian() {
        MainActor.assumeIsolated {
        let (repository, _) = T.repository()
        let c = Self.makeController(repository)
        c.goNext(); c.update { $0.privacyAcknowledged = true }; c.goNext()
        c.update { $0.subject = .myself }; c.goNext()
        c.update { $0.birthDate = T.date(2016, 1, 1) }
        XCTAssertFalse(c.canContinue)
        if case .needsGuardian = c.birthDateValidation {} else { XCTFail() }
        c.switchToGuardianSetup()
        XCTAssertEqual(c.draft.subject, .child)
        XCTAssertEqual(c.currentStep, .nickname)
        XCTAssertEqual(c.draft.birthDate, T.date(2016, 1, 1))
        c.goNext()
        XCTAssertEqual(c.currentStep, .birthDate)
        XCTAssertTrue(c.canContinue)
        }
    }

    func testCurrentHeightDateIsFixedWhenFirstEntered() {
        MainActor.assumeIsolated {
        let (repository, _) = T.repository()
        var now = T.date(2026, 10, 7)
        let c = OnboardingController(repository: repository, now: { now }, calendar: T.calendar)
        c.update { $0.currentHeightCm = 150 }
        let fixed = c.draft.currentHeightDate
        now = T.date(2026, 10, 9)
        c.update { $0.currentHeightCm = 151 }
        XCTAssertEqual(c.draft.currentHeightDate, fixed)
        }
    }

    func testAdditionalChildProfile() {
        MainActor.assumeIsolated {
        var existing = try! ProfileBuilder(flow: T.flow()).build(from: T.completeDraft(subject: .child, birth: T.date(2015, 1, 1)))
        existing.nickname = "Ava"
        let (repository, _) = T.repository(AppSnapshot(profiles: [existing], activeProfileID: existing.id,
                                                       privacyAcknowledgement: PrivacyAcknowledgement(acknowledgedAt: T.today)))
        let c = Self.makeController(repository, mode: .additionalProfile)
        XCTAssertEqual(c.currentStep, .nickname)
        let visited = Self.runToSummary(c, subject: .child, birth: T.date(2019, 9, 9), hasHistory: false)
        XCTAssertFalse(visited.contains(.privacy))
        c.finish()
        XCTAssertEqual(repository.profiles.count, 2)
        XCTAssertEqual(repository.activeProfile?.nickname, "Maya")
        }
    }
}
