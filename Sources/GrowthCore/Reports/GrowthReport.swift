import Foundation
import GrowthEngine

/// The doctor-ready growth report, as data. Built locally from stored measurements; rendered to PDF by
/// `ReportPDFRenderer`. Wording is factual and non-diagnostic (checked by `CopyGuard` in tests).
public struct GrowthReport: Sendable, Equatable {
    public struct Field: Sendable, Equatable {
        public var label: String
        public var value: String
    }

    public struct Table: Sendable, Equatable {
        public var columns: [String]
        public var rows: [[String]]
        public var isEmpty: Bool { rows.isEmpty }
    }

    public struct ChartPoint: Sendable, Equatable {
        public var ageYears: Double
        public var value: Double
    }

    public struct ChartCurve: Sendable, Equatable {
        public var percentile: Int
        public var points: [ChartPoint]
    }

    /// Growth chart data in the report's display unit (cm or inches).
    public struct Chart: Sendable, Equatable {
        public var curves: [ChartCurve]
        public var measurements: [ChartPoint]
        /// Parallel to `measurements`: true where the height was an estimate (drawn hollow).
        public var estimated: [Bool]
        public var ageRange: ClosedRange<Double>
        public var valueRange: ClosedRange<Double>
        public var unitLabel: String
        public var title: String
    }

    public enum SectionStatus: Sendable, Equatable {
        case included
        /// Included, but with a note (e.g. "Needs 6 months between measurements").
        case limited(String)
    }

    public struct SectionSummary: Sendable, Equatable, Identifiable {
        public var number: Int
        public var title: String
        public var status: SectionStatus
        public var id: Int { number }
    }

    public var title: String
    public var subjectName: String
    public var reportDate: Date
    public var reportDateText: String
    public var unit: HeightUnit
    public var cover: [Field]
    public var current: [Field]
    public var chart: Chart?
    public var measurements: Table
    public var percentileHistory: Table
    public var percentileSummary: String
    public var velocity: [String]
    public var velocityTable: Table
    public var family: [String]
    public var scenario: [String]
    public var methodology: [String]
    public var limitations: [String]
    public var questions: [String]
    public var disclaimer: [String]
    public var sections: [SectionSummary]

    /// The four statements every report must carry, on the cover and in the limitations section.
    public static let requiredStatements = [
        "This report is not a diagnosis.",
        "Estimates are not guarantees.",
        "Growth charts provide context, not a verdict on any individual.",
        "This report does not replace evaluation by a qualified healthcare professional."
    ]

    /// Every textual element, for tests and search.
    public var allText: String {
        var parts: [String] = [title, subjectName, reportDateText, percentileSummary]
        parts += (cover + current).flatMap { [$0.label, $0.value] }
        parts += [measurements, percentileHistory, velocityTable].flatMap { $0.columns + $0.rows.flatMap { $0 } }
        parts += velocity + family + scenario + methodology + limitations + questions + disclaimer
        parts += sections.map(\.title)
        return parts.joined(separator: "\n")
    }
}

public struct GrowthReportBuilder: Sendable {
    public var now: Date
    public var calendar: Calendar
    public var locale: Locale

    public init(now: Date, calendar: Calendar, locale: Locale = .current) {
        self.now = now
        self.calendar = calendar
        self.locale = locale
    }

    /// Clinicians mostly read centimetres, so imperial reports show both.
    func height(_ cm: Double, _ unit: HeightUnit) -> String {
        unit == .centimeters
            ? HeightFormatter.string(centimeters: cm, unit: .centimeters)
            : "\(HeightFormatter.string(centimeters: cm, unit: .feetInches)) (\(HeightFormatter.string(centimeters: cm, unit: .centimeters)))"
    }

    func methodText(_ method: MeasurementMethod) -> String {
        switch method {
        case .home: return "Home"
        case .professional: return "Clinic or school"
        case .estimate: return "Estimate"
        }
    }

    public func build(profile: GrowthProfile, unit: HeightUnit? = nil) -> GrowthReport {
        let unit = unit ?? profile.unitPreference
        let analysis = GrowthAnalyzer(now: now, calendar: calendar).analyze(profile)
        let advanced = AdvancedGrowthAnalysis(profile: profile, now: now, calendar: calendar)
        let day = { (d: Date) in DisplayFormat.day(d, calendar: self.calendar, locale: self.locale) }
        let name = profile.nickname?.trimmingCharacters(in: .whitespaces).nilIfEmpty
            ?? (profile.subject == .myself ? "Not recorded" : "Child (name not recorded)")
        let sexText = profile.chartSex == .female ? "Female chart" : "Male chart"
        let ageNow = analysis.age.map { GrowthCopy.ageText(months: $0.exactMonths) } ?? "Not available"

        // Cover
        let cover = [
            GrowthReport.Field(label: "Name", value: name),
            GrowthReport.Field(label: "Date of birth", value: day(profile.birthDate)),
            GrowthReport.Field(label: "Age on report date", value: ageNow),
            GrowthReport.Field(label: "Growth chart", value: "\(sexText), stature-for-age"),
            GrowthReport.Field(label: "Reference", value: analysis.referenceName),
            GrowthReport.Field(label: "Report date", value: day(now)),
            GrowthReport.Field(label: "Units", value: unit == .centimeters ? "Centimetres" : "Feet and inches (centimetres in brackets)")
        ]

        // 1. Current measurement
        var current: [GrowthReport.Field] = []
        if let latest = profile.latestMeasurement {
            current.append(.init(label: "Height", value: height(latest.heightCm, unit)))
            current.append(.init(label: "Measured on", value: day(latest.date)))
            current.append(.init(label: "How it was measured", value: methodText(latest.method)))
            if let ageAt = AgeCalculator.age(birthDate: profile.birthDate, on: latest.date, calendar: calendar) {
                current.append(.init(label: "Age at measurement", value: GrowthCopy.ageText(months: ageAt.exactMonths)))
            }
            if let p = analysis.currentPercentile {
                current.append(.init(label: "Percentile", value: PercentileFormatter.phrase(p.percentile) + String(format: " (z = %+.2f)", p.z)))
            } else {
                current.append(.init(label: "Percentile", value: "Not available (outside the chart's ages 2–20)"))
            }
        }

        // 2. Chart
        let chart = makeChart(analysis: analysis, unit: unit)

        // 3. Measurement history (newest first)
        let measurementRows: [[String]] = profile.sortedMeasurements.reversed().map { m in
            let ageText = AgeCalculator.age(birthDate: profile.birthDate, on: m.date, calendar: calendar).map { GrowthCopy.ageText(months: $0.exactMonths) } ?? "—"
            return [day(m.date), ageText, height(m.heightCm, unit), methodText(m.method)]
        }
        let measurements = GrowthReport.Table(columns: ["Date", "Age", "Height", "Method"], rows: measurementRows)

        // 4. Percentile history (same-day measurements averaged, as on the chart)
        let percentileRows: [[String]] = advanced.percentileHistory.reversed().map { row in
            [day(row.date), GrowthCopy.ageText(months: row.ageMonths), height(row.heightCm, unit),
             PercentileFormatter.ordinal(row.percentile) + (row.isEstimate ? " (estimate)" : ""), String(format: "%+.2f", row.z)]
        }
        let percentileHistory = GrowthReport.Table(columns: ["Date", "Age", "Height", "Percentile", "z-score"], rows: percentileRows)

        // 5. Growth velocity
        var velocity: [String] = []
        switch analysis.velocity {
        case .available(let v):
            velocity.append("Most recent growth speed: about \(GrowthCopy.speed(v.cmPerYear, unit: unit)) per year, from \(day(v.from.date)) to \(day(v.to.date)) (\(v.intervalDays) days).")
            if v.involvesEstimate { velocity.append("One of these heights was an estimate, so this speed is less reliable.") }
        case .needsMoreMeasurements:
            velocity.append("Not available: growth speed needs two measurements at least 6 months apart.")
        case .needsMoreTime(let date):
            velocity.append("Not available yet: measurements need to be at least 6 months apart. A measurement on or after \(day(date)) will allow it.")
        }
        velocity.append("Speeds are annualised from measurements at least 6 months apart, because shorter intervals mostly reflect measuring differences.")
        let velocityTable = GrowthReport.Table(
            columns: ["From", "To", "Change", "Speed per year"],
            rows: advanced.velocityIntervals.reversed().map { [day($0.from), day($0.to), HeightFormatter.changeString(centimeters: $0.changeCm, unit: unit), GrowthCopy.speed($0.cmPerYear, unit: unit)] })

        // 6. Family height
        var family: [String] = []
        switch analysis.family {
        case .available(let f):
            family.append("Family-height range: \(GrowthCopy.range(f.lowCm, f.highCm, unit: unit)), midpoint \(height(f.targetCm, unit)).")
            family.append(GrowthCopy.familyFormula)
            if f.usesEstimatedParentHeight { family.append("At least one parent's height was estimated rather than measured.") }
            family.append("Shown as context only. It is not combined with the estimate below.")
        case .missingParentHeights:
            family.append("Not included: one or both biological parents' heights were not provided.")
        case .notApplicable:
            family.append("Not shown at this age.")
        }

        // 7. Adult-height scenario
        var scenario: [String] = []
        if case .scenario(let s) = analysis.adultHeight {
            scenario.append("Growth-trajectory estimate: \(GrowthCopy.range(s.lowCm, s.highCm, unit: unit)) (\(GrowthCopy.uncertaintyLabel(s.uncertainty).lowercased())).")
            scenario.append(GrowthCopy.scenarioSentence(s))
            scenario.append("Based on the average position of \(s.basisPointCount) measurement\(s.basisPointCount == 1 ? "" : "s") from the past 12 months, projected along the CDC chart to age 20.")
            scenario.append(GrowthCopy.estimateLimit)
        } else if let message = GrowthCopy.outcomeMessage(analysis.adultHeight, isChild: profile.subject == .child) {
            scenario.append("Not shown. \(message.title): \(message.body)")
        } else {
            scenario.append("Not shown for this profile.")
        }
        if advanced.estimateHistory.count >= 2 {
            let parts = advanced.estimateHistory.map { "\(day($0.date)): \(GrowthCopy.range($0.lowCm, $0.highCm, unit: unit))" }
            scenario.append("How the estimate changed as measurements were added: " + parts.joined(separator: "; ") + ".")
        }

        // 8–10
        let methodology = [
            "Reference: \(analysis.referenceName), stature-for-age, ages 2–20 (Kuczmarski et al., 2002). Data version \(String(ReferenceRegistry.cdc2000.dataVersion.prefix(12))).",
            "Percentiles and z-scores use the published LMS parameters: z = ((height ÷ M)^L − 1) ÷ (L × S), with age in days ÷ 30.4375, interpolated between tabulated ages.",
            "Measurements taken on the same day are averaged. Heights marked “Estimate” were entered as best guesses.",
            "Growth speed uses measurements at least 6 months apart, preferring an interval close to 12 months.",
            "The adult-height estimate follows the current percentile channel to age 20. It is a scenario, not a prediction model, and it does not use lifestyle or habit data.",
            "The family-height range uses the Tanner mid-parental method (± 8.5 cm).",
            "All calculations were done on this device. No data was sent to a server to create this report."
        ]
        var limitations = GrowthReport.requiredStatements
        limitations += [
            "Home measurements can differ by a centimetre or more from clinic measurements, depending on technique and time of day.",
            "Percentiles describe position relative to the CDC reference population; they are not a measure of health.",
            "Puberty timing changes growth speed and can move percentiles; the estimate can change substantially around puberty.",
            "The CDC 2000 reference is based on US children measured between 1963 and 1994."
        ]

        var questions = [
            "Is this growth pattern what you would expect at this age and stage of development?",
            "Do the home measurements agree with measurements taken at the clinic?",
            "How often is it useful to measure height from here?"
        ]
        if !analysis.signposts.isEmpty || advanced.percentileRange.map({ $0.upperBound - $0.lowerBound >= 25 }) == true {
            questions.append("The percentile has moved over time. Is that worth looking at more closely?")
        }
        if case .available = analysis.family {
            questions.append("Does family height help explain where this growth sits on the chart?")
        }
        questions.append("Is there anything else, such as general health or puberty timing, that helps interpret this chart?")

        let disclaimer = GrowthReport.requiredStatements + [
            "Measurements were entered by the family in the \(BrandConfig.current.displayName) app."
        ]

        // Section overview for the preview screen
        func status(_ ok: Bool, _ note: String) -> GrowthReport.SectionStatus { ok ? .included : .limited(note) }
        var velocityOK = false
        if case .available = analysis.velocity { velocityOK = true }
        var familyOK = false
        if case .available = analysis.family { familyOK = true }
        var scenarioOK = false
        if case .scenario = analysis.adultHeight { scenarioOK = true }
        let sections = [
            GrowthReport.SectionSummary(number: 1, title: "Current measurement", status: status(!current.isEmpty, "No measurement yet")),
            .init(number: 2, title: "Growth chart", status: status(chart != nil, "Outside the chart's ages 2–20")),
            .init(number: 3, title: "Measurement history", status: .included),
            .init(number: 4, title: "Percentile history", status: status(percentileRows.count >= 2, percentileRows.isEmpty ? "No chart measurements" : "One point so far")),
            .init(number: 5, title: "Growth velocity", status: status(velocityOK, "Needs measurements 6 months apart")),
            .init(number: 6, title: "Family-height context", status: status(familyOK, "Parents' heights not added")),
            .init(number: 7, title: "Adult-height scenario", status: status(scenarioOK, "Not shown at this age or position")),
            .init(number: 8, title: "Methodology", status: .included),
            .init(number: 9, title: "Limitations", status: .included),
            .init(number: 10, title: "Questions for a healthcare professional", status: .included)
        ]

        return GrowthReport(
            title: "Growth Report", subjectName: name, reportDate: now, reportDateText: day(now), unit: unit,
            cover: cover, current: current, chart: chart, measurements: measurements,
            percentileHistory: percentileHistory, percentileSummary: advanced.summary,
            velocity: velocity, velocityTable: velocityTable, family: family, scenario: scenario,
            methodology: methodology, limitations: limitations, questions: questions, disclaimer: disclaimer,
            sections: sections)
    }

    func makeChart(analysis: GrowthAnalysis, unit: HeightUnit) -> GrowthReport.Chart? {
        let points = analysis.series.chartablePoints
        guard !points.isEmpty else { return nil }
        let reference = ReferenceRegistry.cdc2000
        let toUnit = { (cm: Double) in unit == .centimeters ? cm : cm / HeightConversion.centimetersPerInch }
        let ages = points.map { $0.ageMonths / 12 }
        var lo = max(2, (ages.min() ?? 2).rounded(.down) - 1)
        var hi = min(20, (ages.max() ?? 20).rounded(.up) + 2)
        if hi - lo < 5 {
            let pad = (5 - (hi - lo)) / 2
            lo = max(2, lo - pad)
            hi = min(20, lo + 5)
        }
        var curves: [GrowthReport.ChartCurve] = []
        var minV = Double.greatestFiniteMagnitude, maxV = -Double.greatestFiniteMagnitude
        for line in MajorPercentile.allCases {
            var curve: [GrowthReport.ChartPoint] = []
            var age = lo
            while age <= hi + 0.001 {
                if let cm = PercentileCalculator.height(atZ: line.z, ageMonths: age * 12, sex: analysis.sex, reference: reference) {
                    let v = toUnit(cm)
                    curve.append(.init(ageYears: age, value: v))
                    minV = min(minV, v); maxV = max(maxV, v)
                }
                age += 0.25
            }
            curves.append(.init(percentile: line.rawValue, points: curve))
        }
        let measured = points.map { GrowthReport.ChartPoint(ageYears: $0.ageMonths / 12, value: toUnit($0.heightCm)) }
        for p in measured { minV = min(minV, p.value); maxV = max(maxV, p.value) }
        let step = unit == .centimeters ? 10.0 : 4.0
        let vLo = (minV / step).rounded(.down) * step
        let vHi = (maxV / step).rounded(.up) * step
        return GrowthReport.Chart(curves: curves, measurements: measured, estimated: points.map { $0.quality == .estimate },
                                  ageRange: lo...hi, valueRange: vLo...vHi, unitLabel: unit == .centimeters ? "cm" : "in",
                                  title: "Stature-for-age, \(analysis.sex == .female ? "female" : "male"), CDC 2000 percentiles 3–97")
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
