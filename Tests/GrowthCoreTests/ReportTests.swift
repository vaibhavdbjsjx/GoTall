import XCTest
@testable import GrowthCore
import GrowthEngine
#if canImport(PDFKit)
import PDFKit
#endif
#if canImport(ImageIO) && canImport(CoreGraphics)
import ImageIO
import CoreGraphics
#endif

enum ReportFixtures {
    static func teen(unit: HeightUnit = .centimeters, parents: Bool = true) -> GrowthProfile {
        let heights: [(Date, Double, MeasurementMethod)] = [
            (T.date(2023, 9, 10), 141.0, .professional), (T.date(2024, 3, 12), 144.2, .home), (T.date(2024, 9, 8), 147.6, .home),
            (T.date(2025, 3, 15), 150.9, .professional), (T.date(2025, 9, 9), 154.3, .home), (T.date(2026, 3, 10), 156.8, .home),
            (T.date(2026, 9, 7), 159.3, .home)
        ]
        return GrowthProfile(subject: .child, nickname: "Maya", birthDate: T.date(2012, 7, 20), chartSex: .female, unitPreference: unit,
                             measurements: heights.map { HeightMeasurement(date: $0.0, heightCm: $0.1, method: $0.2, origin: .manual) },
                             parentHeights: parents ? ParentHeights(mother: .known(heightCm: 164, source: .measured), father: .known(heightCm: 178, source: .estimated)) : ParentHeights(),
                             createdAt: T.today, updatedAt: T.today)
    }

    static func newcomer() -> GrowthProfile {
        GrowthProfile(subject: .myself, birthDate: T.date(2013, 2, 1), chartSex: .male, unitPreference: .centimeters,
                      measurements: [HeightMeasurement(date: T.date(2026, 9, 30), heightCm: 152, method: .estimate, origin: .onboardingCurrent)],
                      createdAt: T.today, updatedAt: T.today)
    }

    static func adult() -> GrowthProfile {
        GrowthProfile(subject: .myself, birthDate: T.date(1990, 1, 1), chartSex: .male, unitPreference: .centimeters,
                      measurements: [HeightMeasurement(date: T.date(2026, 9, 1), heightCm: 178, method: .home, origin: .manual)],
                      createdAt: T.today, updatedAt: T.today)
    }
}

final class GrowthReportTests: XCTestCase {
    let builder = GrowthReportBuilder(now: T.today, calendar: T.calendar, locale: T.locale)

    func testContentsCoverEverySection() {
        let report = builder.build(profile: ReportFixtures.teen())
        XCTAssertEqual(report.title, "Growth Report")
        XCTAssertEqual(report.subjectName, "Maya")
        XCTAssertEqual(report.subtitle, "Maya")
        XCTAssertGreaterThanOrEqual(report.estimateTable.rows.count, 2)
        XCTAssertTrue(report.methodology[0].contains("sha256:"))
        XCTAssertEqual(report.sections.map(\.number), Array(1...10))
        XCTAssertEqual(report.sections.filter { $0.status != .included }, [], "teen fixture has data for every section")
        XCTAssertTrue(report.cover.contains { $0.label == "Date of birth" })
        XCTAssertTrue(report.cover.contains { $0.label == "Reference" && $0.value.contains("CDC") })
        XCTAssertTrue(report.cover.contains { $0.label == "Report date" })
        XCTAssertEqual(report.measurements.rows.count, 7)
        XCTAssertEqual(report.measurements.rows.first?.first, DisplayFormat.day(T.date(2026, 9, 7), calendar: T.calendar, locale: T.locale), "newest first")
        XCTAssertEqual(report.percentileHistory.rows.count, 7)
        XCTAssertFalse(report.velocityTable.isEmpty)
        XCTAssertTrue(report.velocity[0].contains("per year"))
        XCTAssertTrue(report.family[0].contains("Family-height range"))
        XCTAssertTrue(report.scenario[0].contains("Growth-trajectory estimate"))
        XCTAssertGreaterThanOrEqual(report.questions.count, 4)
        XCTAssertTrue(report.methodology.contains { $0.contains("LMS") })
        XCTAssertTrue(report.methodology.contains { $0.contains("No data was sent") })
    }

    func testRequiredStatementsArePresent() {
        let report = builder.build(profile: ReportFixtures.teen())
        for statement in GrowthReport.requiredStatements {
            XCTAssertTrue(report.disclaimer.contains(statement), statement)
            XCTAssertTrue(report.limitations.contains(statement), statement)
        }
        XCTAssertTrue(report.allText.contains("not a diagnosis"))
        XCTAssertTrue(report.allText.contains("not guarantees"))
        XCTAssertTrue(report.allText.contains("does not replace"))
    }

    func testChartPresence() throws {
        let report = builder.build(profile: ReportFixtures.teen())
        let chart = try XCTUnwrap(report.chart)
        XCTAssertEqual(chart.curves.map(\.percentile), [3, 10, 25, 50, 75, 90, 97])
        XCTAssertEqual(chart.measurements.count, 7)
        XCTAssertEqual(chart.unitLabel, "cm")
        XCTAssertTrue(chart.measurements.allSatisfy { chart.valueRange.contains($0.value) && chart.ageRange.contains($0.ageYears) })
        XCTAssertGreaterThanOrEqual(chart.ageRange.upperBound - chart.ageRange.lowerBound, 5)
        XCTAssertNil(builder.build(profile: ReportFixtures.adult()).chart, "adults are outside the 2–20 chart")
    }

    func testMetricAndImperialUnits() throws {
        let metric = builder.build(profile: ReportFixtures.teen(unit: .centimeters))
        let imperial = builder.build(profile: ReportFixtures.teen(unit: .feetInches))
        XCTAssertEqual(metric.current.first { $0.label == "Height" }?.value, "159.3 cm")
        let imperialHeight = try XCTUnwrap(imperial.current.first { $0.label == "Height" }?.value)
        XCTAssertTrue(imperialHeight.contains("ft"), imperialHeight)
        XCTAssertTrue(imperialHeight.contains("(159.3 cm)"), "imperial reports keep centimetres for clinicians")
        XCTAssertEqual(imperial.chart?.unitLabel, "in")
        let m = try XCTUnwrap(metric.chart?.measurements.last?.value)
        let i = try XCTUnwrap(imperial.chart?.measurements.last?.value)
        XCTAssertEqual(m / i, HeightConversion.centimetersPerInch, accuracy: 0.0001)
        XCTAssertTrue(imperial.velocity[0].contains(" in"))
        XCTAssertEqual(builder.build(profile: ReportFixtures.teen(), unit: .feetInches).unit, .feetInches, "unit can be chosen per report")
    }

    func testMissingDataIsExplainedNotHidden() {
        let report = builder.build(profile: ReportFixtures.newcomer())
        XCTAssertTrue(report.velocity[0].hasPrefix("Not available"))
        XCTAssertTrue(report.family[0].hasPrefix("Not included"))
        XCTAssertTrue(report.velocityTable.isEmpty)
        let limited = report.sections.filter { if case .limited = $0.status { return true }; return false }.map(\.number)
        XCTAssertTrue(limited.contains(5))
        XCTAssertTrue(limited.contains(6))
        XCTAssertTrue(report.percentileHistory.rows.first?[3].contains("estimate") == true)
        XCTAssertEqual(report.subjectName, "Not recorded")
        XCTAssertEqual(report.subtitle, "Personal growth record")
        if let chart = report.chart {
            XCTAssertEqual(chart.ageRange.lowerBound, chart.ageRange.lowerBound.rounded(), "whole-year axis")
            XCTAssertGreaterThanOrEqual(chart.ageRange.upperBound - chart.ageRange.lowerBound, 5)
        }

        let adult = builder.build(profile: ReportFixtures.adult())
        XCTAssertTrue(adult.current.contains { $0.label == "Percentile" && $0.value.hasPrefix("Not available") })
        XCTAssertTrue(adult.scenario[0].hasPrefix("Not shown"))
    }

    func testWordingIsNonDiagnostic() {
        for profile in [ReportFixtures.teen(), ReportFixtures.newcomer(), ReportFixtures.adult()] {
            let text = builder.build(profile: profile).allText
            XCTAssertEqual(CopyGuard.violations(in: text), [])
            for word in ["abnormal", "disorder", "diagnosed", "you will be", "predicts", "deficien"] {
                XCTAssertFalse(text.lowercased().contains(word), word)
            }
        }
    }

    func testAdvancedAnalysisIsRealData() {
        let advanced = AdvancedGrowthAnalysis(profile: ReportFixtures.teen(), now: T.today, calendar: T.calendar)
        XCTAssertEqual(advanced.percentileHistory.count, 7)
        XCTAssertTrue(advanced.hasPattern)
        XCTAssertGreaterThanOrEqual(advanced.velocityIntervals.count, 3, "pairs under 182 days apart are skipped, as for the free speed")
        XCTAssertTrue(advanced.velocityIntervals.allSatisfy { $0.days >= GrowthVelocityCalculator.minimumIntervalDays })
        XCTAssertGreaterThanOrEqual(advanced.estimateHistory.count, 2)
        XCTAssertLessThanOrEqual(advanced.estimateHistory.count, AdvancedGrowthAnalysis.maximumEstimatePoints)
        XCTAssertEqual(advanced.spanMonths, 36)
        let range = advanced.percentileRange!
        XCTAssertTrue(advanced.summary.contains(PercentileFormatter.ordinal(range.lowerBound)))
        XCTAssertTrue(advanced.summary.hasPrefix("Over 36 months"))
        XCTAssertFalse(AdvancedGrowthAnalysis(profile: ReportFixtures.newcomer(), now: T.today, calendar: T.calendar).hasPattern)
    }

    func testHabitsNeverChangeTheReport() {
        var withHabits = ReportFixtures.teen()
        withHabits.habitLog = (0..<20).map { HabitDay(date: T.calendar.date(byAdding: .day, value: -$0, to: T.today)!, completed: HabitKind.allCases) }
        XCTAssertEqual(builder.build(profile: withHabits), builder.build(profile: ReportFixtures.teen()))
    }

    #if canImport(PDFKit) && canImport(ImageIO) && canImport(CoreGraphics)
    func testPDFRendersReadablePagesWithRequiredText() throws {
        for (name, profile) in [("metric", ReportFixtures.teen()), ("imperial", ReportFixtures.teen(unit: .feetInches)), ("sparse", ReportFixtures.newcomer())] {
            let report = builder.build(profile: profile)
            let data = try ReportPDFRenderer.render(report)
            XCTAssertEqual(String(decoding: data.prefix(4), as: UTF8.self), "%PDF")
            let document = try XCTUnwrap(PDFDocument(data: data))
            XCTAssertGreaterThanOrEqual(document.pageCount, 3, name)
            let text = try XCTUnwrap(document.string)
            XCTAssertTrue(text.contains("This report is not a diagnosis."), name)
            XCTAssertTrue(text.contains("Growth chart"), name)
            XCTAssertTrue(text.contains("Page 1 of \(document.pageCount)"), name)
            XCTAssertTrue(text.contains("Questions to discuss with a healthcare professional"), name)
            if let dir = ProcessInfo.processInfo.environment["REPORT_PNG_DIR"] {
                try writePNGs(data: data, prefix: "report-\(name)", to: URL(fileURLWithPath: dir))
            }
        }
    }

    func writePNGs(data: Data, prefix: String, to dir: URL) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let provider = CGDataProvider(data: data as CFData), let pdf = CGPDFDocument(provider) else { return XCTFail("pdf") }
        for index in 1...pdf.numberOfPages {
            guard let page = pdf.page(at: index) else { continue }
            let box = page.getBoxRect(.mediaBox)
            let scale: CGFloat = 1.5
            let w = Int(box.width * scale), h = Int(box.height * scale)
            guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { continue }
            ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            ctx.scaleBy(x: scale, y: scale)
            ctx.drawPDFPage(page)
            guard let image = ctx.makeImage() else { continue }
            let url = dir.appendingPathComponent("\(prefix)-p\(index).png")
            guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { continue }
            CGImageDestinationAddImage(dest, image, nil)
            CGImageDestinationFinalize(dest)
        }
    }
    #endif
}
