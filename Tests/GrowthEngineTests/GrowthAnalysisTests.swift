import XCTest
@testable import GrowthEngine

final class SeriesTests: XCTestCase {
    let birth = E.date(2014, 3, 1)

    func testSortsAndAveragesSameDay() {
        let s = E.series([
            (E.date(2025, 6, 1), 150.0, .home),
            (E.date(2024, 6, 1), 144.0, .professional),
            (E.date(2025, 6, 1), 151.0, .estimate)
        ], birth: birth)
        XCTAssertEqual(s.points.count, 2)
        XCTAssertEqual(s.points.map(\.heightCm), [144.0, 150.5])
        XCTAssertEqual(s.points[1].count, 2)
        XCTAssertEqual(s.points[1].quality, .estimate, "Lowest quality wins when averaging")
        XCTAssertNotNil(s.points[1].percentile)
    }

    func testDropsMeasurementsBeforeBirthAndInvalidHeights() {
        let s = E.series([(E.date(2013, 1, 1), 50.0, .home), (E.date(2025, 1, 1), .nan, .home), (E.date(2025, 2, 1), 140, .home)], birth: birth)
        XCTAssertEqual(s.points.count, 1)
    }

    func testPointsOutsideReferenceHaveNoPercentile() {
        let s = E.series([(E.date(2015, 3, 1), 75.0, .home), (E.date(2017, 3, 1), 95.0, .home)], birth: birth)
        XCTAssertNil(s.points[0].percentile, "Age 1: outside CDC 2–20")
        XCTAssertNotNil(s.points[1].percentile)
        XCTAssertEqual(s.chartablePoints.count, 1)
    }
}

final class VelocityTests: XCTestCase {
    let birth = E.date(2013, 1, 1)

    func testNeedsMoreMeasurements() {
        XCTAssertEqual(GrowthVelocityCalculator.velocity(for: E.series([(E.date(2025, 1, 1), 150, .home)], birth: birth), calendar: E.calendar), .needsMoreMeasurements)
        XCTAssertEqual(GrowthVelocityCalculator.velocity(for: E.series([], birth: birth), calendar: E.calendar), .needsMoreMeasurements)
    }

    func testShortIntervalIsNotAnnualised() {
        let s = E.series([(E.date(2025, 1, 1), 150, .home), (E.date(2025, 4, 1), 152, .home)], birth: birth)
        XCTAssertEqual(GrowthVelocityCalculator.velocity(for: s, calendar: E.calendar), .needsMoreTime(earliestUsefulDate: E.calendar.date(byAdding: .day, value: 182, to: E.calendar.startOfDay(for: E.date(2025, 1, 1)))!))
    }

    func testSameDayDuplicatesNeverCreateVelocity() {
        let s = E.series([(E.date(2025, 1, 1), 150, .home), (E.date(2025, 1, 1), 152, .home)], birth: birth)
        XCTAssertEqual(GrowthVelocityCalculator.velocity(for: s, calendar: E.calendar), .needsMoreMeasurements)
    }

    func testSufficientInterval() {
        let s = E.series([(E.date(2025, 1, 1), 150, .home), (E.date(2026, 1, 1), 156, .home)], birth: birth)
        guard case .available(let v) = GrowthVelocityCalculator.velocity(for: s, calendar: E.calendar) else { return XCTFail() }
        XCTAssertEqual(v.intervalDays, 365)
        XCTAssertEqual(v.changeCm, 6, accuracy: 1e-9)
        XCTAssertEqual(v.cmPerYear, 6 * 365.25 / 365, accuracy: 1e-9)
        XCTAssertEqual(v.direction, .increasing)
        XCTAssertFalse(v.involvesEstimate)
    }

    func testReversedInputOrderGivesSameResult() {
        let forward = E.series([(E.date(2025, 1, 1), 150, .home), (E.date(2025, 9, 1), 154, .home)], birth: birth)
        let reversed = E.series([(E.date(2025, 9, 1), 154, .home), (E.date(2025, 1, 1), 150, .home)], birth: birth)
        XCTAssertEqual(GrowthVelocityCalculator.velocity(for: forward, calendar: E.calendar), GrowthVelocityCalculator.velocity(for: reversed, calendar: E.calendar))
    }

    func testChoosesIntervalClosestToTwelveMonths() {
        let s = E.series([
            (E.date(2023, 1, 1), 140, .home),  // 36 months before latest
            (E.date(2024, 12, 1), 151, .home), // ~13 months before latest
            (E.date(2025, 9, 1), 155, .home),  // 4 months before latest (too short)
            (E.date(2026, 1, 1), 157, .home)
        ], birth: birth)
        guard case .available(let v) = GrowthVelocityCalculator.velocity(for: s, calendar: E.calendar) else { return XCTFail() }
        XCTAssertEqual(v.from.date, E.calendar.startOfDay(for: E.date(2024, 12, 1)))
    }

    func testLittleChangeAndDecrease() {
        let flat = E.series([(E.date(2025, 1, 1), 170, .home), (E.date(2025, 9, 1), 170.3, .home)], birth: birth)
        guard case .available(let v1) = GrowthVelocityCalculator.velocity(for: flat, calendar: E.calendar) else { return XCTFail() }
        XCTAssertEqual(v1.direction, .littleChange)
        let down = E.series([(E.date(2025, 1, 1), 170, .home), (E.date(2025, 9, 1), 168.5, .estimate)], birth: birth)
        guard case .available(let v2) = GrowthVelocityCalculator.velocity(for: down, calendar: E.calendar) else { return XCTFail() }
        XCTAssertEqual(v2.direction, .decreasing)
        XCTAssertTrue(v2.involvesEstimate)
    }
}

final class FamilyHeightTests: XCTestCase {
    func testTannerFormula() {
        let boy = FamilyHeightCalculator.range(motherCm: 165, fatherCm: 180, sex: .male, usesEstimate: false, reference: E.cdc)!
        XCTAssertEqual(boy.targetCm, 179, accuracy: 1e-9)
        XCTAssertEqual(boy.lowCm, 170.5, accuracy: 1e-9)
        XCTAssertEqual(boy.highCm, 187.5, accuracy: 1e-9)
        let girl = FamilyHeightCalculator.range(motherCm: 165, fatherCm: 180, sex: .female, usesEstimate: true, reference: E.cdc)!
        XCTAssertEqual(girl.targetCm, 166, accuracy: 1e-9)
        XCTAssertTrue(girl.usesEstimatedParentHeight)
    }

    func testMissingOrImplausibleParentGivesNothing() {
        XCTAssertNil(FamilyHeightCalculator.range(motherCm: nil, fatherCm: 180, sex: .male, usesEstimate: false, reference: E.cdc))
        XCTAssertNil(FamilyHeightCalculator.range(motherCm: 165, fatherCm: nil, sex: .male, usesEstimate: false, reference: E.cdc))
        XCTAssertNil(FamilyHeightCalculator.range(motherCm: 16.5, fatherCm: 180, sex: .male, usesEstimate: false, reference: E.cdc))
        XCTAssertNil(FamilyHeightCalculator.range(motherCm: 165, fatherCm: 260, sex: .male, usesEstimate: false, reference: E.cdc))
    }

    func testExtremeButPlausibleValues() {
        let r = FamilyHeightCalculator.range(motherCm: 120, fatherCm: 230, sex: .male, usesEstimate: false, reference: E.cdc)!
        XCTAssertEqual(r.targetCm, 181.5, accuracy: 1e-9)
    }

    func testTargetPercentileOnAdultReference() {
        let median = E.cdc.lms(for: .stature, sex: .male, ageMonths: 240)!.m
        // Choose parents so the boy's target equals the adult median.
        let r = FamilyHeightCalculator.range(motherCm: median - 13, fatherCm: median, sex: .male, usesEstimate: false, reference: E.cdc)!
        XCTAssertEqual(r.targetAdultPercentile!.percentile, 50, accuracy: 1e-6)
    }
}

final class ScenarioTests: XCTestCase {
    let birth = E.date(2013, 3, 1)

    func outcome(_ series: GrowthSeries, birth: Date, now: Date, sex: ReferenceSex = .female) -> AdultHeightOutcome {
        let v = GrowthVelocityCalculator.velocity(for: series, calendar: E.calendar)
        return AdultHeightScenarioEngine.outcome(series: series, birthDate: birth, now: now, sex: sex, reference: E.cdc, velocity: v, calendar: E.calendar)
    }

    func testEligibilityByAge() {
        func at(_ years: Int, _ months: Int = 0) -> AdultHeightOutcome {
            let b = E.calendar.date(byAdding: DateComponents(year: -years, month: -months), to: E.date(2026, 10, 1))!
            let s = E.series([(E.date(2026, 9, 1), 120, .home)], birth: b)
            return outcome(s, birth: b, now: E.date(2026, 10, 1))
        }
        XCTAssertEqual(at(1, 6), .unsupportedAge)
        XCTAssertEqual(at(3, 11), .chartOnlyAge)
        if case .scenario = at(4, 1) {} else if case .outsideTypicalRange = at(4, 1) {} else { XCTFail("4y must be eligible") }
        XCTAssertEqual(at(18), .nearAdult(.unknown))
        XCTAssertEqual(at(20, 11), .nearAdult(.unknown))
        XCTAssertEqual(at(21), .adult)
        XCTAssertEqual(at(40), .adult)
    }

    func testNearAdultUsesVelocity() {
        let b = E.date(2007, 1, 1)
        let done = E.series([(E.date(2025, 9, 1), 165.0, .home), (E.date(2026, 9, 1), 165.4, .home)], birth: b)
        XCTAssertEqual(outcome(done, birth: b, now: E.date(2026, 10, 1)), .nearAdult(.growthMostlyComplete))
    }

    func testScenarioChannelForTeenAtMedian() {
        // 15.5-year-old girl exactly at a z of 0.3 → between the 50th and 75th lines (moderate uncertainty, one channel).
        let b = E.date(2011, 3, 1)
        let date = E.date(2026, 9, 1)
        let s = E.series([(date, E.height(z: 0.3, birth: b, on: date), .professional)], birth: b)
        guard case .scenario(let sc) = outcome(s, birth: b, now: E.date(2026, 10, 1)) else { return XCTFail() }
        XCTAssertEqual(sc.lowerLine, .p50)
        XCTAssertEqual(sc.upperLine, .p75)
        XCTAssertEqual(sc.uncertainty, .moderate)
        XCTAssertEqual(sc.lowCm, E.cdc.lms(for: .stature, sex: .female, ageMonths: 240)!.m, accuracy: 1e-9)
        XCTAssertEqual(sc.basisZ, 0.3, accuracy: 1e-6)
        XCTAssertTrue(sc.drivers.contains(.singleMeasurement))
    }

    func testYoungChildGetsWiderTwoChannelRange() {
        // 8-year-old girl at z 0.3 → wider uncertainty → channel widened to 25th–90th.
        let b = E.date(2018, 6, 1)
        let date = E.date(2026, 9, 1)
        let s = E.series([(date, E.height(z: 0.3, birth: b, on: date), .home)], birth: b)
        guard case .scenario(let sc) = outcome(s, birth: b, now: E.date(2026, 10, 1)) else { return XCTFail() }
        XCTAssertEqual(sc.uncertainty, .wider)
        XCTAssertEqual(sc.lowerLine, .p25)
        XCTAssertEqual(sc.upperLine, .p90)
        XCTAssertTrue(sc.drivers.contains(.farFromAdultAge))
        XCTAssertGreaterThan(sc.highCm - sc.lowCm, 10)
    }

    func testEstimatedAndStaleMeasurementsWidenUncertainty() {
        let b = E.date(2009, 9, 1) // 17 at measurement → base narrower
        let date = E.date(2026, 9, 15)
        let measured = E.series([(date, E.height(z: 0.1, birth: b, on: date), .professional)], birth: b)
        guard case .scenario(let a) = outcome(measured, birth: b, now: E.date(2026, 10, 1)) else { return XCTFail() }
        XCTAssertEqual(a.uncertainty, .narrower)
        let estimated = E.series([(date, E.height(z: 0.1, birth: b, on: date), .estimate)], birth: b)
        guard case .scenario(let e) = outcome(estimated, birth: b, now: E.date(2026, 10, 1)) else { return XCTFail() }
        XCTAssertEqual(e.uncertainty, .moderate)
        XCTAssertTrue(e.drivers.contains(.estimatedMeasurement))
        let old = E.date(2026, 2, 1)
        let stale = E.series([(old, E.height(z: 0.1, birth: b, on: old), .professional)], birth: b)
        guard case .scenario(let st) = outcome(stale, birth: b, now: E.date(2026, 10, 1)) else { return XCTFail() }
        XCTAssertTrue(st.drivers.contains(.staleMeasurement))
        XCTAssertEqual(st.uncertainty, .moderate)
    }

    func testShiftingPercentileWidens() {
        let b = E.date(2010, 9, 1) // boy 15–16 → base moderate
        let d1 = E.date(2025, 6, 1), d2 = E.date(2026, 9, 1)
        let s = E.series([(d1, E.height(z: -0.6, birth: b, on: d1, sex: .male), .home),
                          (d2, E.height(z: 0.2, birth: b, on: d2, sex: .male), .home)], birth: b, sex: .male)
        guard case .scenario(let sc) = outcome(s, birth: b, now: E.date(2026, 10, 1), sex: .male) else { return XCTFail() }
        XCTAssertTrue(sc.drivers.contains(.percentileShifting))
        XCTAssertEqual(sc.uncertainty, .wider)
    }

    func testConsistentHistoryNarrowsButNotBelowAgeFloor() {
        let b = E.date(2014, 1, 1) // girl ~11–12 → puberty window: base wider, floor moderate
        let dates = [E.date(2025, 6, 1), E.date(2025, 12, 1), E.date(2026, 9, 1)]
        let s = E.series(dates.map { ($0, E.height(z: 0.4, birth: b, on: $0), MeasurementQuality.professional) }, birth: b)
        guard case .scenario(let sc) = outcome(s, birth: b, now: E.date(2026, 10, 1)) else { return XCTFail() }
        XCTAssertTrue(sc.drivers.contains(.consistentHistory))
        XCTAssertEqual(sc.uncertainty, .moderate, "Puberty-age floor: never narrower than moderate")
        XCTAssertEqual(sc.basisPointCount, 2, "Only points within 12 months of the latest form the basis")
    }

    func testOutsideTypicalRangeShowsNoRange() {
        let b = E.date(2014, 1, 1)
        let d = E.date(2026, 9, 1)
        let s = E.series([(d, E.height(z: -2.3, birth: b, on: d), .professional)], birth: b)
        guard case .outsideTypicalRange(let p) = outcome(s, birth: b, now: E.date(2026, 10, 1)) else { return XCTFail() }
        XCTAssertLessThan(p, 3)
    }

    func testScenarioBasisPrefersMeasuredOverEstimated() {
        let b = E.date(2011, 3, 1)
        let d1 = E.date(2026, 6, 1), d2 = E.date(2026, 9, 1)
        let s = E.series([(d1, E.height(z: 0.3, birth: b, on: d1), .professional), (d2, E.height(z: 1.5, birth: b, on: d2), .estimate)], birth: b)
        guard case .scenario(let sc) = outcome(s, birth: b, now: E.date(2026, 10, 1)) else { return XCTFail() }
        XCTAssertEqual(sc.basisZ, 0.3, accuracy: 1e-6)
    }

    func testNoMeasurementsInRange() {
        let b = E.date(2018, 1, 1)
        XCTAssertEqual(outcome(E.series([], birth: b), birth: b, now: E.date(2026, 10, 1)), .insufficientData)
    }
}

final class SignpostTests: XCTestCase {
    let birth = E.date(2014, 1, 1)

    func testBelowThirdPercentile() {
        let d = E.date(2026, 9, 1)
        XCTAssertEqual(SignpostEngine.signposts(for: E.series([(d, E.height(z: -2.2, birth: birth, on: d), .home)], birth: birth), calendar: E.calendar), [.belowThirdPercentile])
        XCTAssertEqual(SignpostEngine.signposts(for: E.series([(d, E.height(z: 2.2, birth: birth, on: d), .home)], birth: birth), calendar: E.calendar), [.aboveNinetySeventhPercentile])
    }

    func testEstimatesNeverRaiseSignposts() {
        let d = E.date(2026, 9, 1)
        XCTAssertEqual(SignpostEngine.signposts(for: E.series([(d, E.height(z: -2.5, birth: birth, on: d), .estimate)], birth: birth), calendar: E.calendar), [])
    }

    func testDownwardCrossingOfTwoLinesOverAYear() {
        let d1 = E.date(2025, 6, 1), d2 = E.date(2026, 9, 1)
        let s = E.series([(d1, E.height(z: 0.8, birth: birth, on: d1), .professional), (d2, E.height(z: -0.8, birth: birth, on: d2), .professional)], birth: birth)
        guard case .crossedLinesDownward(let lines, let months)? = SignpostEngine.signposts(for: s, calendar: E.calendar).first else { return XCTFail() }
        XCTAssertEqual(lines, 3) // crossed 75th, 50th and 25th
        XCTAssertEqual(months, 15)
    }

    func testNoCrossingSignpostUnderTwelveMonthsOrUpward() {
        let d1 = E.date(2026, 1, 1), d2 = E.date(2026, 9, 1)
        let short = E.series([(d1, E.height(z: 0.8, birth: birth, on: d1), .home), (d2, E.height(z: -0.8, birth: birth, on: d2), .home)], birth: birth)
        XCTAssertEqual(SignpostEngine.signposts(for: short, calendar: E.calendar), [])
        let d0 = E.date(2025, 1, 1)
        let up = E.series([(d0, E.height(z: -0.8, birth: birth, on: d0), .home), (d2, E.height(z: 0.8, birth: birth, on: d2), .home)], birth: birth)
        XCTAssertEqual(SignpostEngine.signposts(for: up, calendar: E.calendar), [])
    }

    func testReferenceCurvesAreOrdered() {
        let curves = ReferenceCurves.curves(sex: .male, reference: E.cdc, ageMonths: 120...180)
        XCTAssertEqual(curves.count, 7)
        let p3 = curves.first { $0.line == .p3 }!.points
        let p97 = curves.first { $0.line == .p97 }!.points
        XCTAssertEqual(p3.count, p97.count)
        for (a, b) in zip(p3, p97) { XCTAssertLessThan(a.heightCm, b.heightCm) }
        XCTAssertTrue(p3.allSatisfy { (120...180).contains($0.ageMonths) })
    }
}
