import XCTest
@testable import GrowthCore
import GrowthEngine

final class WellnessTests: XCTestCase {
    func child(birth: Date = T.date(2016, 4, 1), sex: GrowthChartSex = .female, heights: [(Date, Double)] = [(T.date(2026, 10, 1), 132)]) -> GrowthProfile {
        GrowthProfile(subject: .child, nickname: "Maya", birthDate: birth, chartSex: sex, unitPreference: .centimeters,
                      measurements: heights.map { HeightMeasurement(date: $0.0, heightCm: $0.1, method: .home, origin: .manual) },
                      createdAt: T.today, updatedAt: T.today)
    }

    // MARK: Persistence

    func testOldProfilesWithoutWellnessStillLoad() throws {
        let profile = child()
        var json = try JSONSerialization.jsonObject(with: FileProfileStore.makeEncoder().encode(profile)) as! [String: Any]
        json.removeValue(forKey: "wellness")
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try FileProfileStore.makeDecoder().decode(GrowthProfile.self, from: data)
        XCTAssertEqual(decoded.wellness, .empty)
    }

    func testWellnessRoundTrips() throws {
        var profile = child()
        profile.wellness.routineSessions = [RoutineSession(routineID: "posture-reset", date: T.today, activeSeconds: 300, completed: true)]
        profile.wellness.bedtime = BedtimeSettings(wakeMinutes: 420, remindersOn: true)
        let data = try FileProfileStore.makeEncoder().encode(profile)
        XCTAssertEqual(try FileProfileStore.makeDecoder().decode(GrowthProfile.self, from: data), profile)
    }

    // MARK: Routines

    func testRoutineLibraryIsWellFormedAndHonest() {
        XCTAssertGreaterThanOrEqual(RoutineLibrary.all.count, 8)
        XCTAssertEqual(Set(RoutineLibrary.all.map(\.id)).count, RoutineLibrary.all.count, "routine ids are unique")
        XCTAssertTrue(RoutineLibrary.all.contains { $0.isFree }, "free users always have a routine")
        for routine in RoutineLibrary.all {
            XCTAssertFalse(routine.moves.isEmpty)
            XCTAssertLessThanOrEqual(routine.minutes, 15)
            let text = ([routine.title, routine.subtitle] + routine.moves.flatMap { [$0.name, $0.instruction, $0.cue] }).joined(separator: " ")
            XCTAssertEqual(CopyGuard.violations(in: text), [], routine.id)
        }
    }

    // MARK: Posture

    func testLevelPostureScoresHigh() {
        let points = BodyLandmarks(nose: BodyPoint(x: 0.5, y: 0.8), leftEye: BodyPoint(x: 0.47, y: 0.83), rightEye: BodyPoint(x: 0.53, y: 0.83),
                                   leftShoulder: BodyPoint(x: 0.35, y: 0.65), rightShoulder: BodyPoint(x: 0.65, y: 0.65),
                                   leftHip: BodyPoint(x: 0.4, y: 0.35), rightHip: BodyPoint(x: 0.6, y: 0.35))
        let result = PostureScoring.front(points)!
        XCTAssertEqual(result.score, 100)
        XCTAssertEqual(result.label, "Well aligned")
    }

    func testTiltedShouldersLowerTheScore() {
        let points = BodyLandmarks(leftShoulder: BodyPoint(x: 0.35, y: 0.63), rightShoulder: BodyPoint(x: 0.65, y: 0.68))
        let result = PostureScoring.front(points)!
        XCTAssertEqual(result.shoulderTiltDegrees!, 9.46, accuracy: 0.1)
        XCTAssertLessThan(result.score, 75)
        XCTAssertTrue(result.findings.first!.contains("shoulder"))
    }

    func testForwardHeadFromSide() {
        let upright = PostureScoring.side(BodyLandmarks(leftEar: BodyPoint(x: 0.5, y: 0.8), leftShoulder: BodyPoint(x: 0.49, y: 0.65)))!
        XCTAssertEqual(upright.score, 100)
        let forward = PostureScoring.side(BodyLandmarks(leftEar: BodyPoint(x: 0.6, y: 0.78), leftShoulder: BodyPoint(x: 0.5, y: 0.65)))!
        XCTAssertGreaterThan(forward.forwardHeadDegrees!, 30)
        XCTAssertLessThan(forward.score, 60)
        XCTAssertEqual(RoutineLibrary.suggestions(for: forward.record(at: T.today)).first?.id, "tech-neck")
    }

    func testAveragingIgnoresMissingFrames() {
        let a = BodyLandmarks(leftShoulder: BodyPoint(x: 0.3, y: 0.6), rightShoulder: BodyPoint(x: 0.7, y: 0.6))
        let b = BodyLandmarks(leftShoulder: BodyPoint(x: 0.4, y: 0.6), rightShoulder: nil)
        let mean = PostureScoring.average([a, b])
        XCTAssertEqual(mean.leftShoulder!.x, 0.35, accuracy: 0.0001)
        XCTAssertEqual(mean.rightShoulder!.x, 0.7, accuracy: 0.0001)
        XCTAssertNil(mean.nose)
    }

    // MARK: Bedtime

    func testBedtimeFollowsAgeRecommendation() {
        let teen = BedtimePlanner.plan(settings: BedtimeSettings(wakeMinutes: 7 * 60), ageYears: 15)
        XCTAssertEqual(teen.targetSleepMinutes, 9 * 60)
        XCTAssertEqual(teen.bedtimeMinutes, 21 * 60 + 45, "9 h sleep + 15 min to fall asleep before 7:00")
        XCTAssertEqual(teen.windDownStartMinutes, 21 * 60 + 15)
        let kid = BedtimePlanner.plan(settings: BedtimeSettings(wakeMinutes: 6 * 60 + 30), ageYears: 9)
        XCTAssertEqual(kid.bedtimeMinutes, 20 * 60 + 15)
        XCTAssertEqual(BedtimePlanner.recommendation(ageYears: 30).rangeHours, 7...9)
        XCTAssertEqual(BedtimePlanner.durationText(570), "9 h 30 min")
    }

    // MARK: Outgrow forecast

    func testOutgrowForecastFollowsThePercentileLine() {
        let profile = child()
        let analysis = GrowthAnalyzer(now: T.today, calendar: T.calendar).analyze(profile)
        let forecast = OutgrowForecast.make(profile: profile, analysis: analysis, now: T.today, calendar: T.calendar)!
        XCTAssertEqual(forecast.points.map(\.months), [3, 6, 12])
        let year = forecast.points.last!
        XCTAssertGreaterThan(year.gainCm, 4, "a 10-year-old typically grows 5–6 cm a year")
        XCTAssertLessThan(year.gainCm, 8)
        XCTAssertEqual(forecast.currentSize, "8")
        XCTAssertEqual(forecast.shoeCheckMonths, 4)
        XCTAssertNotNil(forecast.nextSizeChange)
    }

    func testNoForecastForAdults() {
        let adult = child(birth: T.date(1995, 1, 1), heights: [(T.date(2026, 10, 1), 170)])
        let analysis = GrowthAnalyzer(now: T.today, calendar: T.calendar).analyze(adult)
        XCTAssertNil(OutgrowForecast.make(profile: adult, analysis: analysis, now: T.today, calendar: T.calendar))
    }

    func testClothingSizes() {
        XCTAssertEqual(ClothingSize.label(forHeightCm: 95), "3T")
        XCTAssertEqual(ClothingSize.label(forHeightCm: 140), "10")
        XCTAssertEqual(ClothingSize.label(forHeightCm: 175), "Adult sizes")
    }

    // MARK: Progression and plan

    func testPointsLevelsAndForgivingStreak() {
        var profile = child()
        for offset in [0, 1, 2, 4, 5] {
            let day = T.calendar.date(byAdding: .day, value: -offset, to: T.calendar.startOfDay(for: T.today))!
            profile.habitLog.append(HabitDay(date: day, completed: [.sleep, .activity]))
        }
        profile.wellness.routineSessions.append(RoutineSession(routineID: "posture-reset", date: T.today, activeSeconds: 400, completed: true))
        let progression = Progression(profile: profile, today: T.today, calendar: T.calendar)
        XCTAssertEqual(progression.totalPoints, 10 * 10 + 30)
        XCTAssertEqual(progression.level.name, "Starter")
        XCTAssertEqual(progression.activeStreak, 5, "one missed day (3 days ago) is forgiven")
        XCTAssertEqual(progression.activeDaysThisWeek, 5)
        XCTAssertEqual(Progression.level(for: 450).name, "Consistent")
        XCTAssertNil(Progression.level(for: 99_999).nextFloor)
    }

    func testTodayPlanIsStableAndMarksDoneItems() {
        var profile = child()
        let first = TodayPlan.make(profile: profile, analysis: nil, isPremium: false, today: T.today, calendar: T.calendar)
        XCTAssertEqual(first, TodayPlan.make(profile: profile, analysis: nil, isPremium: false, today: T.today, calendar: T.calendar))
        guard case .routine(let id) = first.items[0].kind else { return XCTFail("routine first") }
        XCTAssertTrue(RoutineLibrary.routine(id: id)!.isFree, "free users get free routines")
        profile.wellness.routineSessions.append(RoutineSession(routineID: id, date: T.today, activeSeconds: 300, completed: true))
        for group in [FoodGroup.protein, .fruit, .vegetables] {
            profile = MealLog.toggling(group, on: T.today, in: profile, calendar: T.calendar)
        }
        let after = TodayPlan.make(profile: profile, analysis: nil, isPremium: false, today: T.today, calendar: T.calendar)
        XCTAssertTrue(after.items[0].isDone)
        XCTAssertTrue(after.items.first { $0.kind == .meals }!.isDone)
        XCTAssertTrue(after.items.contains { $0.kind == .postureCheck }, "first posture check is offered")
    }

    func testMealToggleAddsAndRemoves() {
        var profile = child()
        profile = MealLog.toggling(.dairy, on: T.today, in: profile, calendar: T.calendar)
        XCTAssertEqual(MealLog.groups(on: T.today, in: profile, calendar: T.calendar), [.dairy])
        profile = MealLog.toggling(.dairy, on: T.today, in: profile, calendar: T.calendar)
        XCTAssertTrue(profile.wellness.meals.isEmpty)
    }

    // MARK: Puberty, doctor kit, articles

    func testPubertyStages() {
        XCTAssertEqual(PubertyCheck.stage(answers: ["periods": "established"], sex: .female), .late)
        XCTAssertEqual(PubertyCheck.stage(answers: ["periods": "recent"], sex: .female), .middle)
        XCTAssertEqual(PubertyCheck.stage(answers: ["voice": "no", "spurt": "no", "shoes": "no", "skin": "no", "deodorant": "no"], sex: .male), .notStarted)
        XCTAssertEqual(PubertyCheck.stage(answers: ["voice": "no", "spurt": "yes"], sex: .male), .early)
        XCTAssertEqual(PubertyCheck.stage(answers: ["spurt": "unsure", "shoes": "unsure", "skin": "unsure", "voice": "unsure"], sex: .male), .unsure)
        for sex in GrowthChartSex.allCases {
            for subject in ProfileSubject.allCases {
                let text = PubertyCheck.questions(for: sex, subject: subject).map(\.text).joined(separator: " ")
                XCTAssertEqual(CopyGuard.violations(in: text), [])
            }
            for stage in [PubertyStage.notStarted, .early, .middle, .late, .unsure] {
                XCTAssertEqual(CopyGuard.violations(in: PubertyCheck.explanation(stage, sex: sex)), [])
            }
        }
    }

    func testDoctorKitUsesTheProfilesOwnData() {
        let profile = child(heights: [(T.date(2025, 9, 1), 126), (T.date(2026, 10, 1), 132)])
        let analysis = GrowthAnalyzer(now: T.today, calendar: T.calendar).analyze(profile)
        let kit = DoctorVisitKit.make(profile: profile, analysis: analysis, now: T.today, calendar: T.calendar)
        XCTAssertTrue(kit.questions.contains { $0.contains("cm a year") })
        XCTAssertTrue(kit.questions.contains { $0.contains("one parent's height") })
        XCTAssertTrue(kit.plainText(title: "Maya").contains("Bring with you"))
        XCTAssertEqual(CopyGuard.violations(in: kit.plainText(title: "")), [])
    }

    func testArticlesAreSourcedAndHonest() {
        XCTAssertGreaterThanOrEqual(ArticleLibrary.all.count, 10)
        XCTAssertTrue(ArticleLibrary.all.contains { $0.isFree })
        for article in ArticleLibrary.all {
            XCTAssertNotNil(article.sourceURL, article.id)
            XCTAssertEqual(CopyGuard.violations(in: ([article.title, article.summary] + article.paragraphs).joined(separator: " ")), [], article.id)
        }
    }
}
