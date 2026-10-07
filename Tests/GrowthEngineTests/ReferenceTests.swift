import XCTest
@testable import GrowthEngine

enum E {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    static let cdc = CDC2000Reference()

    static func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 9))!
    }

    static func series(_ points: [(Date, Double, MeasurementQuality)], birth: Date, sex: ReferenceSex = .female) -> GrowthSeries {
        GrowthSeries(measurements: points.map { GrowthPoint(date: $0.0, heightCm: $0.1, quality: $0.2) },
                     birthDate: birth, sex: sex, reference: cdc, calendar: calendar)
    }

    /// Height at a given z for someone born `birth`, measured on `date`.
    static func height(z: Double, birth: Date, on date: Date, sex: ReferenceSex = .female) -> Double {
        let age = AgeMath.exactAgeMonths(birthDate: birth, on: date, calendar: calendar)
        return PercentileCalculator.height(atZ: z, ageMonths: age, sex: sex, reference: cdc)!
    }
}

final class CDCReferenceTests: XCTestCase {
    /// z-scores for the published percentile columns P3, P5, P10, P25, P50, P75, P90, P95, P97.
    let publishedZ: [Double] = [-1.880793608151251, -1.6448536269514722, -1.2815515655446004, -0.6744897501960817, 0,
                                0.6744897501960817, 1.2815515655446004, 1.6448536269514722, 1.880793608151251]

    func testDataShapeAndChecksum() {
        XCTAssertEqual(CDC2000StatureData.male.count, 218)
        XCTAssertEqual(CDC2000StatureData.female.count, 218)
        XCTAssertEqual(CDC2000StatureData.male.first?.ageMonths, 24)
        XCTAssertEqual(CDC2000StatureData.male[1].ageMonths, 24.5)
        XCTAssertEqual(CDC2000StatureData.male[2].ageMonths, 25.5)
        XCTAssertEqual(CDC2000StatureData.male.last?.ageMonths, 240)
        XCTAssertEqual(CDC2000StatureData.sourceSHA256, "45130d2a9d7c50c54a47e7ba626b66c61d4554bc2d901198cedd9419a53f7251")
        let ages = CDC2000StatureData.female.map(\.ageMonths)
        XCTAssertEqual(ages, ages.sorted(), "Ages must be strictly increasing")
    }

    /// The core validation: LMS maths reproduces every CDC-published percentile, for every row and both sexes.
    func testLMSReproducesEveryPublishedPercentile() {
        var worst = 0.0
        for row in CDC2000StatureData.male + CDC2000StatureData.female {
            for (z, published) in zip(publishedZ, row.publishedPercentiles) {
                let value = row.lms.value(atZ: z)!
                worst = max(worst, abs(value - published))
                // And the inverse: published height → z.
                XCTAssertEqual(row.lms.zScore(for: published), z, accuracy: 1e-6)
            }
        }
        XCTAssertLessThan(worst, 1e-6, "Worst deviation \(worst) cm")
    }

    func testAdultMedians() {
        XCTAssertEqual(E.cdc.lms(for: .stature, sex: .male, ageMonths: 240)!.m, 176.8492322, accuracy: 1e-9)
        XCTAssertEqual(E.cdc.lms(for: .stature, sex: .female, ageMonths: 240)!.m, 163.338251, accuracy: 1e-9)
    }

    func testCoverageBoundaries() {
        XCTAssertEqual(E.cdc.coverage(for: .stature, sex: .male), 24...240)
        XCTAssertNotNil(E.cdc.lms(for: .stature, sex: .male, ageMonths: 24))
        XCTAssertNotNil(E.cdc.lms(for: .stature, sex: .male, ageMonths: 240))
        XCTAssertNil(E.cdc.lms(for: .stature, sex: .male, ageMonths: 23.99))
        XCTAssertNil(E.cdc.lms(for: .stature, sex: .male, ageMonths: 240.01))
        XCTAssertNil(E.cdc.lms(for: .stature, sex: .male, ageMonths: .nan))
    }

    func testLinearInterpolationBetweenRows() {
        let a = CDC2000StatureData.female[10].lms
        let b = CDC2000StatureData.female[11].lms
        let midAge = (CDC2000StatureData.female[10].ageMonths + CDC2000StatureData.female[11].ageMonths) / 2
        let mid = E.cdc.lms(for: .stature, sex: .female, ageMonths: midAge)!
        XCTAssertEqual(mid.l, (a.l + b.l) / 2, accuracy: 1e-12)
        XCTAssertEqual(mid.m, (a.m + b.m) / 2, accuracy: 1e-12)
        XCTAssertEqual(mid.s, (a.s + b.s) / 2, accuracy: 1e-12)
        // Exact tabulated ages return the row itself.
        XCTAssertEqual(E.cdc.lms(for: .stature, sex: .female, ageMonths: CDC2000StatureData.female[10].ageMonths), a)
    }

    func testMedianIncreasesSmoothlyWithAge() {
        var previous = 0.0
        for month in stride(from: 24.0, through: 240.0, by: 0.25) {
            let m = E.cdc.lms(for: .stature, sex: .male, ageMonths: month)!.m
            XCTAssertGreaterThanOrEqual(m, previous - 1e-9, "Median dropped at \(month)")
            previous = m
        }
    }

    func testMajorPercentileZValues() {
        for line in MajorPercentile.allCases {
            XCTAssertEqual(StandardNormal.cdf(line.z) * 100, Double(line.rawValue), accuracy: 1e-9)
        }
    }

    func testRegistryUsesCDCAtLaunch() {
        XCTAssertEqual(ReferenceRegistry.reference(forRegion: "US").id, "CDC2000")
        XCTAssertEqual(ReferenceRegistry.reference(forRegion: nil).id, "CDC2000")
    }
}

final class PercentileTests: XCTestCase {
    func testMedianIsFiftiethPercentile() throws {
        let m = E.cdc.lms(for: .stature, sex: .male, ageMonths: 150)!.m
        let result = try PercentileCalculator.percentile(heightCm: m, ageMonths: 150, sex: .male, reference: E.cdc).get()
        XCTAssertEqual(result.z, 0, accuracy: 1e-12)
        XCTAssertEqual(result.percentile, 50, accuracy: 1e-9)
        XCTAssertEqual(result.referenceID, "CDC2000")
    }

    func testPublishedNinetiethPercentileRoundTrips() throws {
        let row = CDC2000StatureData.female[100]
        let result = try PercentileCalculator.percentile(heightCm: row.publishedPercentiles[6], ageMonths: row.ageMonths, sex: .female, reference: E.cdc).get()
        XCTAssertEqual(result.percentile, 90, accuracy: 1e-4)
    }

    func testErrors() {
        XCTAssertEqual(PercentileCalculator.percentile(heightCm: 90, ageMonths: 20, sex: .male, reference: E.cdc), .failure(.ageBelowReference(minimumMonths: 24)))
        XCTAssertEqual(PercentileCalculator.percentile(heightCm: 170, ageMonths: 250, sex: .male, reference: E.cdc), .failure(.ageAboveReference(maximumMonths: 240)))
        XCTAssertEqual(PercentileCalculator.percentile(heightCm: -5, ageMonths: 100, sex: .male, reference: E.cdc), .failure(.invalidHeight))
        XCTAssertEqual(PercentileCalculator.percentile(heightCm: .infinity, ageMonths: 100, sex: .male, reference: E.cdc), .failure(.invalidHeight))
    }

    func testSexSpecific() throws {
        let boy = try PercentileCalculator.percentile(heightCm: 160, ageMonths: 168, sex: .male, reference: E.cdc).get()
        let girl = try PercentileCalculator.percentile(heightCm: 160, ageMonths: 168, sex: .female, reference: E.cdc).get()
        XCTAssertNotEqual(boy.percentile, girl.percentile, accuracy: 1)
    }

    func testFormatterAvoidsFalsePrecision() {
        XCTAssertEqual(PercentileFormatter.ordinal(63.4821), "63rd")
        XCTAssertEqual(PercentileFormatter.ordinal(50.0), "50th")
        XCTAssertEqual(PercentileFormatter.ordinal(1.2), "1st")
        XCTAssertEqual(PercentileFormatter.ordinal(2), "2nd")
        XCTAssertEqual(PercentileFormatter.ordinal(11), "11th")
        XCTAssertEqual(PercentileFormatter.ordinal(12.4), "12th")
        XCTAssertEqual(PercentileFormatter.ordinal(13), "13th")
        XCTAssertEqual(PercentileFormatter.ordinal(21), "21st")
        XCTAssertEqual(PercentileFormatter.ordinal(0.3), "below the 1st")
        XCTAssertEqual(PercentileFormatter.ordinal(99.7), "above the 99th")
        XCTAssertEqual(PercentileFormatter.phrase(63.4821), "63rd percentile")
    }

    func testAgeMath() {
        let birth = E.date(2014, 1, 1)
        XCTAssertEqual(AgeMath.days(from: birth, to: E.date(2015, 1, 1), calendar: E.calendar), 365)
        XCTAssertEqual(AgeMath.exactAgeMonths(birthDate: birth, on: E.date(2016, 1, 1), calendar: E.calendar), 730 / 30.4375, accuracy: 1e-9)
    }
}
