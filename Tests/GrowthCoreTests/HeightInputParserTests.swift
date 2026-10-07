import XCTest
@testable import GrowthCore

final class HeightInputParserTests: XCTestCase {
    func testCentimetres() {
        XCTAssertEqual(HeightInputParser.centimeters("152.4"), 152.4)
        XCTAssertEqual(HeightInputParser.centimeters("152,4"), 152.4)
        XCTAssertEqual(HeightInputParser.centimeters(" 160 "), 160)
        XCTAssertEqual(HeightInputParser.centimeters("160.06"), 160.1)
        XCTAssertNil(HeightInputParser.centimeters(""))
        XCTAssertNil(HeightInputParser.centimeters("1.2.3"))
        XCTAssertNil(HeightInputParser.centimeters("abc"))
        XCTAssertNil(HeightInputParser.centimeters("-150"))
    }

    func testFeetInches() {
        XCTAssertEqual(HeightInputParser.centimeters(feet: "5", inches: "7.5"), 171.5)
        XCTAssertEqual(HeightInputParser.centimeters(feet: "5", inches: ""), 152.4)
        XCTAssertNil(HeightInputParser.centimeters(feet: "5", inches: "12"), "Inches must be under 12")
        XCTAssertNil(HeightInputParser.centimeters(feet: "5.5", inches: "0"), "Feet must be whole")
        XCTAssertNil(HeightInputParser.centimeters(feet: "", inches: "6"))
    }

    func testFieldTextRoundTripsWithoutDrift() {
        // Switching cm → ft/in → cm in the UI re-reads the stored value; it never re-parses the display.
        let stored = 163.7
        XCTAssertEqual(HeightInputParser.fieldText(centimeters: stored), "163.7")
        let imperial = HeightInputParser.fieldText(feetInchesFrom: stored)
        XCTAssertEqual(imperial.feet, "5")
        XCTAssertEqual(imperial.inches, "4.5")
        XCTAssertEqual(HeightInputParser.fieldText(centimeters: stored), "163.7")
    }
}
