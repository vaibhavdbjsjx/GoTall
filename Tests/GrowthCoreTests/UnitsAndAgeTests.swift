import XCTest
@testable import GrowthCore

final class HeightConversionTests: XCTestCase {
    func testFeetInchesToCentimetres() {
        XCTAssertEqual(HeightConversion.centimeters(feet: 5, inches: 0), 152.4)
        XCTAssertEqual(HeightConversion.centimeters(feet: 6, inches: 0), 182.9)
        XCTAssertEqual(HeightConversion.centimeters(feet: 5, inches: 7.5), 171.5)
    }

    func testCentimetresToFeetInchesSnapsToHalfInch() {
        XCTAssertEqual(HeightConversion.feetInches(fromCentimeters: 152.4), FeetInches(feet: 5, inches: 0))
        XCTAssertEqual(HeightConversion.feetInches(fromCentimeters: 171.5), FeetInches(feet: 5, inches: 7.5))
        // 182.8 cm = 71.97 in → snaps to 72 in → 6 ft 0 in (no "5 ft 12 in").
        XCTAssertEqual(HeightConversion.feetInches(fromCentimeters: 182.8), FeetInches(feet: 6, inches: 0))
    }

    func testSwitchingUnitsNeverChangesStoredValue() {
        // Units are display-only; the stored cm value is the source of truth.
        let stored = 163.7
        let displayed = HeightConversion.feetInches(fromCentimeters: stored)
        XCTAssertEqual(displayed, FeetInches(feet: 5, inches: 4.5))
        XCTAssertEqual(HeightFormatter.string(centimeters: stored, unit: .centimeters), "163.7 cm")
        // Re-entering the displayed imperial value gives a nearby but not identical value, which is
        // why the UI only converts when the person actually edits in that unit.
        XCTAssertEqual(abs(HeightConversion.centimeters(feet: displayed.feet, inches: displayed.inches) - stored), 0.4, accuracy: 0.5)
    }

    func testRoundTripThroughImperialEntryIsStable() {
        for totalHalfInches in stride(from: 48, through: 168, by: 1) {
            let inches = Double(totalHalfInches) / 2 + 24
            let feet = Int(inches / 12)
            let cm = HeightConversion.centimeters(feet: feet, inches: inches - Double(feet) * 12)
            let back = HeightConversion.feetInches(fromCentimeters: cm)
            XCTAssertEqual(Double(back.feet) * 12 + back.inches, inches, accuracy: 0.001, "\(inches) in")
        }
    }

    func testFormatting() {
        XCTAssertEqual(HeightFormatter.string(centimeters: 152.4, unit: .feetInches), "5 ft 0 in")
        XCTAssertEqual(HeightFormatter.string(centimeters: 171.5, unit: .feetInches), "5 ft 7.5 in")
        XCTAssertEqual(HeightFormatter.accessibleString(centimeters: 152.4, unit: .centimeters), "152.4 centimetres")
        XCTAssertEqual(HeightFormatter.accessibleString(centimeters: 152.4, unit: .feetInches), "5 feet 0 inches")
        XCTAssertEqual(HeightFormatter.changeString(centimeters: 3.24, unit: .centimeters), "+3.2 cm")
        XCTAssertEqual(HeightFormatter.changeString(centimeters: 2.54, unit: .feetInches), "+1 in")
    }

    func testMeasurementRoundsToStoragePrecision() {
        let measurement = HeightMeasurement(date: T.today, heightCm: 150.04999, method: .home, origin: .manual)
        XCTAssertEqual(measurement.heightCm, 150.0)
    }
}

final class HeightValidationTests: XCTestCase {
    func testBounds() {
        XCTAssertEqual(HeightValidation.validate(nil), .missing)
        XCTAssertEqual(HeightValidation.validate(.nan), .missing)
        XCTAssertEqual(HeightValidation.validate(59.9), .tooShort)
        XCTAssertEqual(HeightValidation.validate(60), .valid)
        XCTAssertEqual(HeightValidation.validate(250), .valid)
        XCTAssertEqual(HeightValidation.validate(250.1), .tooTall)
        // A classic unit mix-up: feet typed into the cm field.
        XCTAssertEqual(HeightValidation.validate(5.5), .tooShort)
        XCTAssertEqual(HeightValidation.validate(110, range: HeightValidation.parentRange), .tooShort)
    }
}

final class AgeTests: XCTestCase {
    func testAgeCalculation() {
        let age = AgeCalculator.age(birthDate: T.date(2011, 3, 15), on: T.today, calendar: T.calendar)
        XCTAssertEqual(age?.years, 15)
        XCTAssertEqual(age?.months, 6)
        XCTAssertEqual(age?.band, .teen)
        XCTAssertEqual(age!.exactMonths, 186.7, accuracy: 0.1)
    }

    func testBirthdayBoundary() {
        let birth = T.date(2013, 10, 7, hour: 0)
        XCTAssertEqual(AgeCalculator.age(birthDate: birth, on: T.date(2026, 10, 6), calendar: T.calendar)?.years, 12)
        XCTAssertEqual(AgeCalculator.age(birthDate: birth, on: T.date(2026, 10, 7), calendar: T.calendar)?.years, 13)
    }

    func testAgeBands() {
        XCTAssertEqual(AgeBand(years: 1), .infant)
        XCTAssertEqual(AgeBand(years: 2), .child)
        XCTAssertEqual(AgeBand(years: 12), .child)
        XCTAssertEqual(AgeBand(years: 13), .teen)
        XCTAssertEqual(AgeBand(years: 17), .teen)
        XCTAssertEqual(AgeBand(years: 18), .youngAdult)
        XCTAssertEqual(AgeBand(years: 20), .youngAdult)
        XCTAssertEqual(AgeBand(years: 21), .adult)
    }

    func testBirthDateValidation() {
        func check(_ birth: Date?, _ subject: ProfileSubject?) -> BirthDateValidation {
            BirthDateValidation.validate(birth, subject: subject, today: T.today, calendar: T.calendar)
        }
        XCTAssertEqual(check(nil, .myself), .missing)
        XCTAssertEqual(check(T.date(2027, 1, 1), .myself), .inFuture)
        XCTAssertEqual(check(T.date(1920, 1, 1), .myself), .implausiblyOld)
        XCTAssertEqual(check(T.date(2025, 6, 1), .child), .tooYoung)
        if case .needsGuardian = check(T.date(2016, 1, 1), .myself) {} else { XCTFail("Under-13 self setup must need a guardian") }
        XCTAssertNotNil(check(T.date(2016, 1, 1), .child).age, "Parents can set up under-13 profiles")
        XCTAssertNotNil(check(T.date(2011, 1, 1), .myself).age)
        XCTAssertNotNil(check(T.date(1990, 1, 1), .myself).age)
    }
}
