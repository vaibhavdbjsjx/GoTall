import XCTest
@testable import GrowthCore

final class OnboardingFlowTests: XCTestCase {
    let flow = T.flow()

    func testTeenSelfSeesGrowthQuestionsButNoNickname() {
        var draft = T.draft(subject: .myself, birth: T.date(2011, 3, 15))
        draft.hasHistory = false
        let steps = flow.visibleSteps(for: draft)
        XCTAssertFalse(steps.contains(.nickname))
        XCTAssertTrue(steps.contains(.parentHeights))
        XCTAssertTrue(steps.contains(.historyQuestion))
        XCTAssertFalse(steps.contains(.historyEntry), "No history → no history entry screen")
        XCTAssertTrue(steps.contains(.growthChange))
        XCTAssertFalse(steps.contains(.concernSupport))
    }

    func testParentFlowAddsNickname() {
        let draft = T.draft(subject: .child, birth: T.date(2018, 5, 1))
        XCTAssertTrue(flow.visibleSteps(for: draft).contains(.nickname))
    }

    func testAdultSkipsChildDevelopmentQuestions() {
        let draft = T.draft(subject: .myself, birth: T.date(1995, 1, 1))
        let steps = flow.visibleSteps(for: draft)
        XCTAssertFalse(steps.contains(.parentHeights))
        XCTAssertFalse(steps.contains(.historyQuestion))
        XCTAssertFalse(steps.contains(.historyEntry))
        XCTAssertFalse(steps.contains(.growthChange))
        XCTAssertTrue(steps.contains(.sleep))
        XCTAssertTrue(steps.contains(.goals))
    }

    func testYoungAdultGetsHistoryButNotParentHeights() {
        let draft = T.draft(subject: .myself, birth: T.date(2007, 1, 1)) // 19
        let steps = flow.visibleSteps(for: draft)
        XCTAssertFalse(steps.contains(.parentHeights))
        XCTAssertTrue(steps.contains(.historyQuestion))
        XCTAssertTrue(steps.contains(.growthChange))
    }

    func testUnknownAgeShowsAgeDependentStepsTentatively() {
        let draft = T.draft(subject: .myself, birth: nil)
        XCTAssertTrue(flow.visibleSteps(for: draft).contains(.parentHeights))
    }

    func testHistoryEntryAppearsOnlyWhenAnsweredYes() {
        var draft = T.draft()
        draft.hasHistory = true
        XCTAssertTrue(flow.visibleSteps(for: draft).contains(.historyEntry))
        XCTAssertEqual(flow.next(after: .historyQuestion, in: draft), .historyEntry)
        draft.hasHistory = false
        XCTAssertEqual(flow.next(after: .historyQuestion, in: draft), .growthChange)
    }

    func testConcernAddsSupportStep() {
        var draft = T.draft()
        draft.intent = .concerned
        XCTAssertEqual(flow.next(after: .intent, in: draft), .concernSupport)
        draft.intent = .curious
        XCTAssertEqual(flow.next(after: .intent, in: draft), .buildingProfile)
    }

    func testAdditionalProfileSkipsIntroductionAndSubject() {
        let draft = T.draft(mode: .additionalProfile)
        let steps = flow.visibleSteps(for: draft)
        XCTAssertEqual(draft.subject, .child)
        XCTAssertEqual(steps.first, .nickname)
        XCTAssertFalse(steps.contains(.welcome))
        XCTAssertFalse(steps.contains(.privacy))
        XCTAssertFalse(steps.contains(.subject))
    }

    func testRequiredStepsBlockContinue() {
        var draft = T.draft(subject: nil, birth: nil)
        draft.privacyAcknowledged = false
        XCTAssertFalse(flow.canContinue(from: .privacy, in: draft))
        XCTAssertFalse(flow.canContinue(from: .subject, in: draft))
        XCTAssertFalse(flow.canContinue(from: .birthDate, in: draft))
        XCTAssertFalse(flow.canContinue(from: .chartSex, in: draft))
        XCTAssertFalse(flow.canContinue(from: .currentHeight, in: draft))
        XCTAssertFalse(flow.canContinue(from: .historyQuestion, in: draft))
        // Optional steps never block.
        XCTAssertTrue(flow.canContinue(from: .sleep, in: draft))
        XCTAssertTrue(flow.canContinue(from: .goals, in: draft))
    }

    func testFutureAndImpossibleBirthDatesBlock() {
        var draft = T.draft(birth: T.date(2030, 1, 1))
        XCTAssertFalse(flow.canContinue(from: .birthDate, in: draft))
        draft.birthDate = T.date(1900, 1, 1)
        XCTAssertFalse(flow.canContinue(from: .birthDate, in: draft))
        draft.birthDate = T.date(2016, 1, 1) // 10, self
        XCTAssertFalse(flow.canContinue(from: .birthDate, in: draft))
        draft.subject = .child
        XCTAssertTrue(flow.canContinue(from: .birthDate, in: draft))
    }

    func testInvalidHeightBlocks() {
        var draft = T.draft()
        draft.currentHeightCm = 5.4
        XCTAssertFalse(flow.canContinue(from: .currentHeight, in: draft))
        draft.currentHeightCm = 400
        XCTAssertFalse(flow.canContinue(from: .currentHeight, in: draft))
        draft.currentHeightCm = 160
        XCTAssertTrue(flow.canContinue(from: .currentHeight, in: draft))
    }

    func testMissingParentHeightsAreFineButInvalidOnesBlock() {
        var draft = T.draft()
        XCTAssertTrue(flow.canContinue(from: .parentHeights, in: draft))
        draft.mother = .unknown
        draft.father = .known(heightCm: 178, source: .estimated)
        XCTAssertTrue(flow.canContinue(from: .parentHeights, in: draft))
        draft.father = .known(heightCm: 17.8, source: .estimated)
        XCTAssertFalse(flow.canContinue(from: .parentHeights, in: draft))
    }

    func testProgressIsChapterBasedAndMonotonic() {
        var draft = T.completeDraft()
        var last = -1.0
        var chapters: [OnboardingChapter] = []
        for step in flow.visibleSteps(for: draft) {
            draft.currentStep = step
            let progress = flow.progress(for: draft)
            if step.chapter == .introduction {
                XCTAssertNil(progress.chapterIndex)
                continue
            }
            XCTAssertGreaterThanOrEqual(progress.overall, last, "\(step)")
            last = progress.overall
            if chapters.last != progress.chapter { chapters.append(progress.chapter) }
        }
        XCTAssertEqual(chapters, OnboardingChapter.tracked)
    }

    func testEditingReturnsToSummaryUnlessANewQuestionBecameRelevant() {
        var draft = T.completeDraft()
        draft.editingFromSummary = true
        XCTAssertEqual(flow.nextWhileEditing(after: .sleep, in: draft), .summary)
        draft.hasHistory = true
        XCTAssertEqual(flow.nextWhileEditing(after: .historyQuestion, in: draft), .historyEntry)
        draft.intent = .concerned
        XCTAssertEqual(flow.nextWhileEditing(after: .intent, in: draft), .concernSupport)
    }
}

final class HistoryValidationTests: XCTestCase {
    let flow = T.flow()

    func testBlankRowsAreIgnored() {
        var draft = T.completeDraft()
        draft.hasHistory = true
        draft.history = [HistoryEntryDraft()]
        XCTAssertTrue(flow.canContinue(from: .historyEntry, in: draft))
    }

    func testPartialRowBlocks() {
        var draft = T.completeDraft()
        draft.hasHistory = true
        draft.history = [HistoryEntryDraft(date: T.date(2025, 1, 1), heightCm: nil)]
        XCTAssertFalse(flow.canContinue(from: .historyEntry, in: draft))
        XCTAssertEqual(flow.historyIssues(for: draft).values.first, [.missingHeight])
    }

    func testDateRules() {
        var draft = T.completeDraft(birth: T.date(2011, 3, 15))
        let before = HistoryEntryDraft(date: T.date(2010, 1, 1), heightCm: 50 + 20)
        let future = HistoryEntryDraft(date: T.date(2027, 1, 1), heightCm: 150)
        let sameDay = HistoryEntryDraft(date: T.today, heightCm: 150)
        draft.history = [before, future, sameDay]
        let issues = flow.historyIssues(for: draft)
        XCTAssertTrue(issues[before.id]!.contains(.dateBeforeBirth))
        XCTAssertTrue(issues[future.id]!.contains(.dateInFuture))
        XCTAssertTrue(issues[sameDay.id]!.contains(.dateNotBeforeCurrentMeasurement))
    }

    func testDuplicateDates() {
        var draft = T.completeDraft()
        let a = HistoryEntryDraft(date: T.date(2025, 5, 1, hour: 8), heightCm: 150)
        let b = HistoryEntryDraft(date: T.date(2025, 5, 1, hour: 18), heightCm: 151)
        draft.history = [a, b]
        XCTAssertEqual(flow.historyIssues(for: draft)[a.id], [.duplicateDate])
    }

    func testTallerThanCurrentIsAWarningNotABlock() {
        var draft = T.completeDraft()
        let entry = HistoryEntryDraft(date: T.date(2025, 5, 1), heightCm: 165)
        draft.history = [entry]
        XCTAssertTrue(flow.canContinue(from: .historyEntry, in: draft))
        XCTAssertEqual(HistoryValidation.warnings(for: entry, currentHeightCm: draft.currentHeightCm), [.tallerThanCurrent])
        XCTAssertEqual(HistoryValidation.warnings(for: entry, currentHeightCm: 164), [])
    }
}
