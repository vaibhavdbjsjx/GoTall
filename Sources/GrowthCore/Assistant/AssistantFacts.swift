import Foundation
import GrowthEngine

/// Everything the assistant may say about this person, taken from the same engine as the rest of the app.
/// The on-device model only ever sees `brief`; the built-in guide reads the fields directly. Lifestyle answers
/// (sleep, meals, activity) never produce a height number.
public struct AssistantFacts: Sendable, Equatable {
    public var subjectName: String
    /// Possessive used in answers: "Maya's" or "your".
    public var possessive: String
    public var isChildProfile: Bool
    public var isUnder13: Bool
    public var stillGrowing: Bool
    public var ageText: String?
    public var heightText: String?
    public var measuredText: String?
    public var latestIsEstimate: Bool
    public var percentileOrdinal: String?
    public var percentileValue: Int?
    public var speedText: String?
    public var speedUnavailable: String?
    public var estimateRange: String?
    public var estimateSentence: String?
    public var estimateUncertainty: String?
    public var estimateUnavailable: String?
    public var familyText: String?
    public var nextMeasurementText: String?
    public var weekText: String?
    public var mostConsistentHabit: String?
    public var concernSignposts: [String]
    public var unit: HeightUnit

    public init(profile: GrowthProfile, now: Date, calendar: Calendar, locale: Locale = .current) {
        let analysis = GrowthAnalyzer(now: now, calendar: calendar).analyze(profile)
        let unit = profile.unitPreference
        self.unit = unit
        isChildProfile = profile.subject == .child
        let name = profile.nickname?.trimmingCharacters(in: .whitespaces)
        subjectName = isChildProfile ? (name?.isEmpty == false ? name! : "your child") : "you"
        possessive = isChildProfile ? (name?.isEmpty == false ? "\(name!)'s" : "your child's") : "your"
        isUnder13 = (analysis.age?.years ?? 99) < 13
        stillGrowing = analysis.age?.band.isStillGrowing ?? false
        ageText = analysis.age.map { GrowthCopy.ageText(months: $0.exactMonths) }

        if let latest = profile.latestMeasurement {
            heightText = HeightFormatter.string(centimeters: latest.heightCm, unit: unit)
            measuredText = DisplayFormat.day(latest.date, calendar: calendar, locale: locale)
        }
        latestIsEstimate = analysis.latestIsEstimate
        if let p = analysis.currentPercentile {
            percentileOrdinal = PercentileFormatter.ordinal(p.percentile)
            percentileValue = min(max(Int(p.percentile.rounded()), 1), 99)
        }

        switch analysis.velocity {
        case .available(let v):
            speedText = "about \(GrowthCopy.speed(v.cmPerYear, unit: unit)) per year (\(DisplayFormat.monthYear(v.from.date, calendar: calendar, locale: locale)) to \(DisplayFormat.monthYear(v.to.date, calendar: calendar, locale: locale)))"
        case .needsMoreMeasurements:
            speedUnavailable = "Growth speed needs two measurements at least 6 months apart."
        case .needsMoreTime(let date):
            speedUnavailable = "Growth speed will be available after a measurement on or after \(DisplayFormat.day(date, calendar: calendar, locale: locale))."
        }

        if case .scenario(let s) = analysis.adultHeight {
            estimateRange = GrowthCopy.range(s.lowCm, s.highCm, unit: unit)
            estimateSentence = GrowthCopy.scenarioSentence(s)
            estimateUncertainty = GrowthCopy.uncertaintyLabel(s.uncertainty).lowercased()
        } else if let message = GrowthCopy.outcomeMessage(analysis.adultHeight, isChild: isChildProfile) {
            estimateUnavailable = "\(message.title). \(message.body)"
        }

        if case .available(let f) = analysis.family {
            familyText = "Family-height range \(GrowthCopy.range(f.lowCm, f.highCm, unit: unit)) (from both parents' heights; context only, not combined with the estimate)."
        }
        if let next = analysis.nextMeasurement {
            nextMeasurementText = next.isDue ? "A new measurement is due now." : "Next measurement around \(DisplayFormat.day(next.suggestedDate, calendar: calendar, locale: locale))."
        }
        let engine = HabitEngine(today: now, calendar: calendar)
        let days = engine.checkInDaysThisWeek(in: profile)
        weekText = "\(days) of 7 days with a habit check-in this week."
        mostConsistentHabit = engine.mostConsistent(in: profile)?.kind.title
        concernSignposts = analysis.signposts.map(GrowthCopy.signpostText)
    }

    /// The factual brief handed to the on-device model. Every number the model may mention appears here.
    public var brief: String {
        var lines: [String] = []
        lines.append(isChildProfile
            ? "Profile: \(subjectName), a child. The person asking is their parent or caregiver."
            : "Profile: the person asking, tracking their own growth.")
        if let ageText { lines.append("Age: \(ageText).") }
        if let heightText, let measuredText {
            lines.append("Latest height: \(heightText), on \(measuredText)\(latestIsEstimate ? " (an estimate, not a careful measurement)" : "").")
        }
        if let percentileOrdinal, let percentileValue {
            lines.append("Percentile on the CDC 2000 growth chart: \(percentileOrdinal). Of 100 people the same age and sex, about \(percentileValue) are shorter. The typical range on the chart is the 3rd to the 97th percentile.")
        } else {
            lines.append("No percentile: the CDC chart covers ages 2 to 20.")
        }
        lines.append("Growth speed: " + (speedText ?? speedUnavailable ?? "not available."))
        if let estimateRange, let estimateSentence, let estimateUncertainty {
            lines.append("Adult-height estimate: \(estimateRange), \(estimateUncertainty). \(estimateSentence) It is not a guarantee; puberty timing can change it.")
        } else if let estimateUnavailable {
            lines.append("Adult-height estimate: not shown. \(estimateUnavailable)")
        }
        if let familyText { lines.append(familyText) }
        if let nextMeasurementText { lines.append(nextMeasurementText) }
        if let weekText { lines.append("Habits: \(weekText)" + (mostConsistentHabit.map { " Most consistent: \($0)." } ?? "")) }
        if !concernSignposts.isEmpty { lines.append("Worth discussing with a doctor: " + concernSignposts.joined(separator: " ")) }
        return lines.joined(separator: "\n")
    }
}
