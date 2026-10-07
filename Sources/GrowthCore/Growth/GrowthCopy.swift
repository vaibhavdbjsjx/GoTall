import Foundation
import GrowthEngine

/// Plain-language text for growth results. All wording passes `CopyGuard` (tested).
public enum GrowthCopy {
    // MARK: Formatting

    /// "5.8 cm" or "2.3 in" (one decimal), used for speeds and changes.
    public static func speed(_ cmPerYear: Double, unit: HeightUnit) -> String {
        unit == .centimeters
            ? String(format: "%.1f cm", cmPerYear)
            : String(format: "%.1f in", cmPerYear / HeightConversion.centimetersPerInch)
    }

    /// Range "163–168 cm" or "5 ft 4 in – 5 ft 6 in". Rounded to whole cm / half inches: no false precision.
    public static func range(_ low: Double, _ high: Double, unit: HeightUnit) -> String {
        switch unit {
        case .centimeters:
            return "\(Int(low.rounded()))–\(Int(high.rounded())) cm"
        case .feetInches:
            return "\(HeightFormatter.compactImperial(centimeters: low))–\(HeightFormatter.compactImperial(centimeters: high))"
        }
    }

    public static func accessibleRange(_ low: Double, _ high: Double, unit: HeightUnit) -> String {
        switch unit {
        case .centimeters: return "from \(Int(low.rounded())) to \(Int(high.rounded())) centimetres"
        case .feetInches:
            return "from \(HeightFormatter.accessibleString(centimeters: low, unit: .feetInches)) to \(HeightFormatter.accessibleString(centimeters: high, unit: .feetInches))"
        }
    }

    public static func ageText(months exactMonths: Double) -> String {
        let total = Int(exactMonths.rounded(.down))
        return "\(total / 12)y \(total % 12)m"
    }

    // MARK: Adult-height estimate

    public static let estimateTitle = "Estimated adult height"
    public static let estimateDisclaimer = "This is a growth-trajectory estimate, not a guarantee."
    public static let estimateBasis = "It's based on the current growth pattern on the CDC growth chart."
    public static let estimateLimit = "Actual adult height can differ, especially around puberty, when growth speed changes."

    public static func scenarioSentence(_ scenario: AdultHeightScenario) -> String {
        "If growth stays between the \(PercentileFormatter.ordinal(Double(scenario.lowerLine.rawValue))) and \(PercentileFormatter.ordinal(Double(scenario.upperLine.rawValue))) percentile lines, adult height would be in this range."
    }

    public static func uncertaintyLabel(_ level: UncertaintyLevel) -> String {
        switch level {
        case .narrower: return "Narrower range"
        case .moderate: return "Moderate range"
        case .wider: return "Wider range"
        }
    }

    public static func uncertaintyExplanation(_ level: UncertaintyLevel) -> String {
        switch level {
        case .narrower: return "Most growth has usually happened by this age, so the range is narrower. It's still not a guarantee."
        case .moderate: return "Some growth is still ahead, so the range covers one percentile channel."
        case .wider: return "A lot can still change, so the range covers a wider band of percentile lines."
        }
    }

    public static func driverText(_ driver: UncertaintyDriver) -> String {
        switch driver {
        case .farFromAdultAge: return "Several years of growth are still ahead."
        case .pubertyAgeWindow: return "This is a common age for puberty, when percentile positions often shift."
        case .lateAdolescence: return "Most growth usually happens before this age."
        case .estimatedMeasurement: return "It relies on an estimated height rather than a measurement."
        case .staleMeasurement: return "The latest measurement is more than 6 months old."
        case .singleMeasurement: return "There's only one recent measurement, so consistency can't be checked yet."
        case .percentileShifting: return "The percentile position has moved over the past year."
        case .consistentHistory: return "Recent measurements have followed a steady path."
        }
    }

    public static func outcomeMessage(_ outcome: AdultHeightOutcome, isChild: Bool) -> (title: String, body: String)? {
        switch outcome {
        case .scenario: return nil
        case .unsupportedAge:
            return ("Adult height estimate", "The growth charts used here start at age 2.")
        case .chartOnlyAge:
            return ("Adult height estimate", "Estimates start at age 4. Until then, measurements build the growth chart.")
        case .nearAdult(.growthMostlyComplete):
            return ("Near adult height", "Growth over the past months has been under 1 cm a year, so most growth appears to be complete.")
        case .nearAdult(.stillGrowing(let speed)):
            return ("Near adult height", "Still growing at about \(String(format: "%.1f", speed)) cm a year. Growth usually slows and stops in the next few years.")
        case .nearAdult(.unknown):
            return ("Near adult height", "Most growth is usually complete by now. Measurements 6 months or more apart will show whether height is still changing.")
        case .adult:
            return ("Adult height", "Measured height is adult height, so there's nothing to estimate.")
        case .outsideTypicalRange(let percentile):
            let side = percentile < 50 ? "below the 3rd" : "above the 97th"
            return ("Adult height estimate", "The current height is \(side) percentile. Estimates are least reliable at the edges of the chart, so no range is shown. A pediatrician can look at growth in context.")
        case .insufficientData:
            return ("Adult height estimate", "Add a measurement to see an estimate.")
        }
    }

    // MARK: Explanation ("Why this estimate?")

    public struct ExplanationItem: Sendable, Equatable, Identifiable {
        public var symbol: String
        public var title: String
        public var detail: String
        public var id: String { title }
    }

    public struct Explanation: Sendable, Equatable {
        public var used: [ExplanationItem]
        public var contextOnly: [ExplanationItem]
        public var notUsed: [ExplanationItem]
    }

    public static func explanation(for analysis: GrowthAnalysis, scenario: AdultHeightScenario, locale: Locale = .current, calendar: Calendar) -> Explanation {
        var used: [ExplanationItem] = []
        if let latest = analysis.latest {
            used.append(.init(symbol: "ruler", title: "Current height",
                              detail: "\(HeightFormatter.string(centimeters: latest.heightCm, unit: analysis.unit)) on \(DisplayFormat.day(latest.date, calendar: calendar, locale: locale))\(latest.quality == .estimate ? " (estimate)" : "")"))
            used.append(.init(symbol: "calendar", title: "Age at that measurement", detail: ageText(months: latest.ageMonths)))
        }
        used.append(.init(symbol: "chart.xyaxis.line", title: "Growth chart",
                          detail: "\(analysis.referenceName), \(analysis.sex == .female ? "female" : "male") chart. Adult values are taken at age 20."))
        used.append(.init(symbol: "clock.arrow.circlepath", title: "Recent measurements",
                          detail: scenario.basisPointCount == 1
                            ? "One measurement from the past 12 months."
                            : "Average position of \(scenario.basisPointCount) measurements from the past 12 months."))

        var context: [ExplanationItem] = []
        if case .available = analysis.family {
            context.append(.init(symbol: "person.2", title: "Family height",
                                 detail: "Shown separately as context. It isn't averaged into the estimate."))
        }

        let notUsed: [ExplanationItem] = [
            .init(symbol: "moon", title: "Sleep, activity and eating",
                  detail: "These don't change the height estimate shown here. They're tracked separately as healthy-development habits."),
            .init(symbol: "target", title: "Goals and reasons for using the app", detail: "Used only to personalise the app."),
            .init(symbol: "arrow.up.right", title: "Growth changes you noticed", detail: "Used only to help explain the trend.")
        ]
        return Explanation(used: used, contextOnly: context, notUsed: notUsed)
    }

    public static let methodSummary = """
    We find the current position on the CDC growth chart for age and sex (the percentile). The estimate shows the adult heights at age 20 for the percentile lines on either side of that position. When more can still change, the range widens to the next line on each side. No AI is involved, and nothing is averaged with family height.
    """

    // MARK: Family height

    public static let familyTitle = "Family-height range"
    public static let familyExplanation = "Height runs in families. This range comes from both biological parents' heights. It describes the family, not a promise for one person."
    public static let familyFormula = "Midpoint = (mother + father ± 13 cm) ÷ 2, adding 13 cm for boys and subtracting it for girls. Range = midpoint ± 8.5 cm (Tanner method)."
    public static let familyLimitations = "It tends to overestimate for very tall parents and underestimate for very short parents, and remembered heights are often a little high. Most people end up within this range, not all."
    public static let familyMissing = "Add both biological parents' heights to see a family-height range. If they aren't known, everything else still works."

    // MARK: Velocity

    public static let velocityTitle = "Growth speed"
    public static func velocitySentence(_ v: VelocityResult, unit: HeightUnit) -> String {
        let months = max(1, Int((Double(v.intervalDays) / 30.4375).rounded()))
        switch v.direction {
        case .increasing: return "About \(speed(v.cmPerYear, unit: unit)) per year, based on measurements \(months) months apart."
        case .littleChange: return "Little change over \(months) months."
        case .decreasing: return "Lower than \(months) months ago, which is usually a measuring difference."
        }
    }
    public static let velocityNeedsMore = "Not enough measurements yet. Growth speed needs two measurements at least 6 months apart."

    // MARK: Safety

    public static func signpostText(_ signpost: GrowthSignpost) -> String {
        switch signpost {
        case .belowThirdPercentile:
            return "The latest height is below the 3rd percentile line. Many children here are healthy and simply smaller, but it's worth mentioning at the next check-up."
        case .aboveNinetySeventhPercentile:
            return "The latest height is above the 97th percentile line. Many children here are healthy and simply taller, but it's worth mentioning at the next check-up."
        case .crossedLinesDownward(let lines, let months):
            return "Over \(months) months the position moved down across \(lines) percentile lines. Measuring differences can cause this; if it's confirmed by careful measurements, it's worth showing a pediatrician."
        }
    }
    public static let concernBody = "Growth varies considerably, and one measurement isn't enough to judge anything. If you're concerned about the growth pattern, a pediatrician or other qualified health professional can review these measurements in context."

    // MARK: Measurement quality

    public static let estimatedNotice = "The current height was estimated. A careful measurement will make the growth chart more useful."
}
