import XCTest
@testable import GrowthCore

@MainActor
final class FakeAssistantModel: AssistantModel {
    var availability: AssistantAvailability
    var reply: String
    var error: Error?
    var calls: [(instructions: String, prompt: String)] = []

    init(availability: AssistantAvailability = .available, reply: String = "") {
        self.availability = availability
        self.reply = reply
    }

    func respond(instructions: String, prompt: String) async throws -> String {
        calls.append((instructions, prompt))
        if let error { throw error }
        return reply
    }
}

struct FakeModelError: Error {}

enum AssistantFixtures {
    static var facts: AssistantFacts { AssistantFacts(profile: ReportFixtures.teen(), now: T.today, calendar: T.calendar, locale: T.locale) }
}

final class AssistantFactsAndGuideTests: XCTestCase {
    func testBriefContainsEngineFactsOnly() {
        let f = AssistantFixtures.facts
        XCTAssertTrue(f.isChildProfile)
        XCTAssertEqual(f.subjectName, "Maya")
        XCTAssertEqual(f.heightText, "159.3 cm")
        XCTAssertNotNil(f.percentileOrdinal)
        XCTAssertNotNil(f.estimateRange)
        XCTAssertNotNil(f.speedText)
        XCTAssertTrue(f.brief.contains("159.3 cm"))
        XCTAssertTrue(f.brief.contains("parent or caregiver"))
        XCTAssertTrue(f.brief.contains("not a guarantee"))
    }

    func testHabitsNeverChangeTheBriefNumbers() {
        var busy = ReportFixtures.teen()
        busy.habitLog = (0..<20).map { HabitDay(date: T.calendar.date(byAdding: .day, value: -$0, to: T.today)!, completed: HabitKind.allCases) }
        let a = AssistantFacts(profile: busy, now: T.today, calendar: T.calendar, locale: T.locale)
        let b = AssistantFixtures.facts
        XCTAssertEqual(a.estimateRange, b.estimateRange)
        XCTAssertEqual(a.percentileOrdinal, b.percentileOrdinal)
        XCTAssertEqual(a.speedText, b.speedText)
        XCTAssertEqual(a.heightText, b.heightText)
    }

    func testIntentRouting() {
        XCTAssertEqual(AssistantGuide.intent(for: "How tall will Maya be?"), .estimate)
        XCTAssertEqual(AssistantGuide.intent(for: "is she normal for her age"), .percentile)
        XCTAssertEqual(AssistantGuide.intent(for: "how do I grow taller fast"), .taller)
        XCTAssertEqual(AssistantGuide.intent(for: "when do growth plates close"), .stopGrowing)
        XCTAssertEqual(AssistantGuide.intent(for: "best food for growth?"), .nutrition)
        XCTAssertEqual(AssistantGuide.intent(for: "does basketball help"), .exercise)
        XCTAssertEqual(AssistantGuide.intent(for: "how often should we measure"), .measuring)
        XCTAssertEqual(AssistantGuide.intent(for: "should I see a doctor"), .doctor)
        XCTAssertEqual(AssistantGuide.intent(for: "hello"), .summary)
    }

    func testGuideAnswersUseRealNumbersAndPassTheGuard() {
        let f = AssistantFixtures.facts
        let questions = ["How tall might Maya be as an adult?", "Is her growth on track?", "How fast is she growing?", "How can she grow taller?",
                         "How much sleep?", "What should she eat?", "Does swimming help?", "When should we measure next?",
                         "When will she stop growing?", "I'm worried", "How do I share a report?", "hi"]
        for q in questions {
            let answer = AssistantGuide.answer(q, facts: f)
            XCTAssertFalse(answer.isEmpty, q)
            XCTAssertEqual(CopyGuard.violations(in: answer), [], q)
            XCTAssertNil(AssistantOutputGuard.check(answer, brief: f.brief + " 3rd 97th 1 cm 9 12 8 10 6"), "\(q): \(answer)")
        }
        XCTAssertTrue(AssistantGuide.answer("How tall will she be?", facts: f).contains(f.estimateRange!))
        XCTAssertTrue(AssistantGuide.answer("Is she normal?", facts: f).contains(f.percentileOrdinal!))
        let taller = AssistantGuide.answer("how to get taller", facts: f).lowercased()
        XCTAssertTrue(taller.contains("no food"))
        XCTAssertFalse(taller.contains("calorie"))
    }

    func testSuggestionsFitTheProfile() {
        let child = AssistantGuide.suggestions(for: AssistantFixtures.facts)
        XCTAssertTrue(child.contains("How tall might Maya be as an adult?"))
        XCTAssertLessThanOrEqual(child.count, 5)
        for s in child { XCTAssertEqual(CopyGuard.violations(in: s), [], s) }
        let adult = AssistantGuide.suggestions(for: AssistantFacts(profile: ReportFixtures.adult(), now: T.today, calendar: T.calendar))
        XCTAssertFalse(adult.contains { $0.contains("adult?") }, "no estimate for adults")
    }
}

final class AssistantSafetyTests: XCTestCase {
    func testCrisisEatingEmergencyAndHarmfulMethodsGetFixedAnswers() {
        guard case .fixed(.crisis, let crisis) = AssistantSafety.classify("I want to die because I'm short") else { return XCTFail() }
        XCTAssertTrue(crisis.contains("988"))
        guard case .fixed(.eatingDisorder, _) = AssistantSafety.classify("should I stop eating to look taller") else { return XCTFail() }
        guard case .fixed(.emergency, let emergency) = AssistantSafety.classify("I have chest pain") else { return XCTFail() }
        XCTAssertTrue(emergency.contains("911"))
        guard case .fixed(.harmfulGrowthMethod, let hgh) = AssistantSafety.classify("where can I buy HGH") else { return XCTFail() }
        XCTAssertTrue(hgh.contains("pediatrician"))
        XCTAssertEqual(AssistantSafety.classify("how tall will I be"), .allowed)
    }

    func testGuardRejectsInventedNumbersAndClaims() {
        let brief = AssistantFixtures.facts.brief
        XCTAssertEqual(AssistantOutputGuard.check("She will probably reach 175 cm.", brief: brief), .inventedNumber("175.0"))
        XCTAssertEqual(AssistantOutputGuard.check("She is around the 80th percentile.", brief: brief), .inventedNumber("80.0"))
        XCTAssertNotNil(AssistantOutputGuard.check("You will be tall, I promise.", brief: brief))
        XCTAssertNotNil(AssistantOutputGuard.check("Try growth hormone.", brief: brief))
        XCTAssertNotNil(AssistantOutputGuard.check("A 1200 calorie diet helps.", brief: brief))
        XCTAssertNotNil(AssistantOutputGuard.check("These stretches will help you grow taller.", brief: brief))
        XCTAssertEqual(AssistantOutputGuard.check("   ", brief: brief), .empty)
        XCTAssertEqual(AssistantOutputGuard.check(String(repeating: "a", count: 2000), brief: brief), .tooLong)
    }

    func testGuardAcceptsGroundedAnswers() {
        let f = AssistantFixtures.facts
        let ok = "Maya's latest height is 159.3 cm, around the \(f.percentileOrdinal!) percentile, which is within the typical 3rd to 97th range. That's not a diagnosis; a pediatrician can help with worries."
        XCTAssertNil(AssistantOutputGuard.check(ok, brief: f.brief))
        XCTAssertNil(AssistantOutputGuard.check("Sleep and meals support growth, but no exercise makes you taller beyond genetics.", brief: f.brief))
        XCTAssertNil(AssistantOutputGuard.check("If growth stays on this path, the estimate is \(f.estimateRange!), not a guarantee.", brief: f.brief))
    }
}

final class AssistantSessionTests: XCTestCase {
    @MainActor
    func testOnDeviceAnswerIsUsedWhenItPassesTheGuard() async {
        let model = FakeAssistantModel(reply: "Maya's latest height is 159.3 cm. Measuring every few months keeps the picture clear.")
        let session = AssistantSession(model: model, usage: InMemoryAssistantUsageStore(), calendar: T.calendar, now: { T.today })
        await session.send("How is Maya doing?", facts: AssistantFixtures.facts, isPremium: false)
        XCTAssertEqual(session.messages.count, 2)
        XCTAssertEqual(session.messages.last?.source, .onDevice)
        XCTAssertTrue(model.calls[0].instructions.contains("159.3 cm"), "facts are grounded in the instructions")
        XCTAssertTrue(model.calls[0].instructions.contains("Never invent"))
        XCTAssertEqual(session.remainingFree(isPremium: false), 2)
    }

    @MainActor
    func testRejectedOrFailedModelAnswersFallBackToTheGuide() async {
        let model = FakeAssistantModel(reply: "She will reach 180 cm for sure.")
        let session = AssistantSession(model: model, usage: InMemoryAssistantUsageStore(), calendar: T.calendar, now: { T.today })
        await session.send("How tall will she be?", facts: AssistantFixtures.facts, isPremium: false)
        XCTAssertEqual(session.messages.last?.source, .guide)
        XCTAssertFalse(session.messages.last!.text.contains("180"))
        model.error = FakeModelError()
        await session.send("Is she on track?", facts: AssistantFixtures.facts, isPremium: false)
        XCTAssertEqual(session.messages.last?.source, .guide)
    }

    @MainActor
    func testUnavailableModelUsesGuideWithoutCallingIt() async {
        let model = FakeAssistantModel(availability: .deviceNotEligible, reply: "x")
        let session = AssistantSession(model: model, usage: InMemoryAssistantUsageStore(), calendar: T.calendar, now: { T.today })
        await session.send("When should we measure?", facts: AssistantFixtures.facts, isPremium: false)
        XCTAssertTrue(model.calls.isEmpty)
        XCTAssertEqual(session.messages.last?.source, .guide)
        XCTAssertNotNil(session.availability.explanation)
        XCTAssertNil(AssistantAvailability.available.explanation)
    }

    @MainActor
    func testSafetyBypassesModelAndAllowance() async {
        let model = FakeAssistantModel(reply: "x")
        let usage = InMemoryAssistantUsageStore()
        let session = AssistantSession(model: model, usage: usage, calendar: T.calendar, now: { T.today })
        await session.send("I want to hurt myself", facts: AssistantFixtures.facts, isPremium: false)
        XCTAssertEqual(session.messages.last?.source, .safety)
        XCTAssertTrue(model.calls.isEmpty)
        XCTAssertEqual(session.remainingFree(isPremium: false), 3, "safety answers never use up free questions")
    }

    @MainActor
    func testDailyAllowanceAndPremium() async {
        let usage = InMemoryAssistantUsageStore()
        let session = AssistantSession(model: nil, usage: usage, calendar: T.calendar, now: { T.today })
        for _ in 0..<3 { await session.send("Is she on track?", facts: AssistantFixtures.facts, isPremium: false) }
        XCTAssertEqual(session.remainingFree(isPremium: false), 0)
        await session.send("One more?", facts: AssistantFixtures.facts, isPremium: false)
        XCTAssertTrue(session.messages.last!.isLimitNotice)
        await session.send("And as Premium?", facts: AssistantFixtures.facts, isPremium: true)
        XCTAssertEqual(session.messages.last?.source, .guide)
        XCTAssertNil(session.remainingFree(isPremium: true))
        let tomorrow = AssistantSession(model: nil, usage: usage, calendar: T.calendar, now: { T.date(2026, 10, 8) })
        XCTAssertEqual(tomorrow.remainingFree(isPremium: false), 3, "allowance resets daily")
    }

    @MainActor
    func testEmptyAndLongQuestions() async {
        let session = AssistantSession(model: nil, usage: InMemoryAssistantUsageStore(), calendar: T.calendar, now: { T.today })
        await session.send("   ", facts: AssistantFixtures.facts, isPremium: false)
        XCTAssertTrue(session.messages.isEmpty)
        await session.send(String(repeating: "x", count: 900), facts: AssistantFixtures.facts, isPremium: false)
        XCTAssertEqual(session.messages.first?.text.count, AssistantSession.maximumQuestionLength)
    }

    func testPromptKeepsTheRules() {
        let text = AssistantPrompt.instructions(facts: AssistantFixtures.facts)
        for rule in ["Never invent", "Do not diagnose", "Never recommend medicines", "not a guarantee"] {
            XCTAssertTrue(text.contains(rule) || text.lowercased().contains(rule.lowercased()), rule)
        }
    }
}
