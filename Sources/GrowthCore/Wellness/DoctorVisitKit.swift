import Foundation
import GrowthEngine

/// Prepares for a check-up: questions worth asking (built from this profile's own data) and a short list of what
/// to bring. Pairs with the PDF report. Questions are phrased for the clinician to answer; the app never diagnoses.
public struct DoctorVisitKit: Sendable, Equatable {
    public var questions: [String]
    public var bring: [String]

    public static func make(profile: GrowthProfile, analysis: GrowthAnalysis, now: Date, calendar: Calendar) -> DoctorVisitKit {
        var questions: [String] = []
        let name = profile.subject == .myself ? "my" : "my child's"

        for signpost in analysis.signposts {
            switch signpost {
            case .belowThirdPercentile:
                questions.append("The latest height is below the 3rd percentile. Is any follow-up or a bone-age X-ray worth considering?")
            case .aboveNinetySeventhPercentile:
                questions.append("The latest height is above the 97th percentile. Is that expected given our family heights?")
            case .crossedLinesDownward(let lines, let months):
                questions.append("Height crossed \(lines) percentile lines downward over \(months) months. Should we look into that?")
            }
        }

        if case .available(let velocity) = analysis.velocity {
            let speed = String(format: "%.1f", velocity.cmPerYear)
            questions.append("Growth over the last measured period was about \(speed) cm a year. Is that typical for \(name) age and stage?")
        } else {
            questions.append("Can you measure height today so we have a professional measurement to compare against at home?")
        }

        switch profile.wellness.puberty?.stage {
        case .some(.notStarted), .some(.early):
            questions.append("Where do you think \(name == "my" ? "I am" : "they are") in puberty, and how much growth is usually left from here?")
        case .some(.late):
            questions.append("Growth seems to be slowing. Are the growth plates likely to be closing soon?")
        default:
            questions.append("How much growth is usually left at this age and stage of puberty?")
        }

        if !profile.parentHeights.bothKnown {
            questions.append("Does the family-height range change much if we only know one parent's height?")
        }
        if let latest = profile.wellness.latestPostureCheck, latest.score < 70 {
            questions.append("A posture self-check showed some imbalance. Is it worth a physiotherapy check, or is stretching enough?")
        }
        questions.append("Are sleep, activity and diet on track for healthy growth at this age?")

        let bring = [
            "The Gromax growth report (PDF), or this phone",
            "Any earlier heights from school, sports or past check-ups",
            "Both parents' heights if you know them",
            "A list of medicines or supplements taken regularly"
        ]
        return DoctorVisitKit(questions: questions, bring: bring)
    }

    /// Plain text for sharing or copying into Notes.
    public func plainText(title: String) -> String {
        var lines = ["\(title)", "", "Questions to ask"]
        lines += questions.enumerated().map { "\($0.offset + 1). \($0.element)" }
        lines += ["", "Bring with you"]
        lines += bring.map { "• \($0)" }
        return lines.joined(separator: "\n")
    }
}
