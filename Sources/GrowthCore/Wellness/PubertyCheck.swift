import Foundation

/// A short puberty check with non-intimate questions only: no body photos, no questions about private body parts,
/// every question can be skipped with "Not sure". The result is a rough description of where someone may be,
/// used to explain how much growth is usually left. It is never an input to the height estimate.
public enum PubertyCheck {
    public struct Option: Sendable, Equatable, Identifiable {
        public var id: String
        public var title: String
    }

    public struct Question: Sendable, Equatable, Identifiable {
        public var id: String
        public var text: String
        public var options: [Option]
    }

    static let yes = Option(id: "yes", title: "Yes")
    static let no = Option(id: "no", title: "No")
    static let unsure = Option(id: "unsure", title: "Not sure")

    public static func questions(for sex: GrowthChartSex, subject: ProfileSubject) -> [Question] {
        let you = subject == .myself
        var list = [
            Question(id: "spurt", text: you ? "Have you had a noticeable growth spurt in the last year?" : "Have they had a noticeable growth spurt in the last year?",
                     options: [yes, no, unsure]),
            Question(id: "shoes", text: you ? "Has your shoe size gone up quickly recently?" : "Has their shoe size gone up quickly recently?",
                     options: [yes, no, unsure]),
            Question(id: "skin", text: you ? "Have you noticed spots or oilier skin?" : "Have they noticed spots or oilier skin?",
                     options: [yes, no, unsure]),
            Question(id: "deodorant", text: you ? "Have you started needing deodorant?" : "Have they started needing deodorant?",
                     options: [yes, no, unsure])
        ]
        switch sex {
        case .female:
            list.append(Question(id: "periods", text: you ? "Have your periods started?" : "Have their periods started?",
                                 options: [no, Option(id: "recent", title: "Yes, in the last year"), Option(id: "established", title: "Yes, over a year ago"),
                                           Option(id: "unsure", title: "Prefer not to say")]))
        case .male:
            list.append(Question(id: "voice", text: you ? "Has your voice started to change?" : "Has their voice started to change?",
                                 options: [no, Option(id: "changing", title: "It's changing now"), Option(id: "settled", title: "Yes, it's settled deeper"), unsure]))
        }
        return list
    }

    public static func stage(answers: [String: String], sex: GrowthChartSex) -> PubertyStage {
        let signs = ["spurt", "shoes", "skin", "deodorant"].filter { answers[$0] == "yes" }.count
        let unsureCount = answers.values.filter { $0 == "unsure" }.count
        switch sex {
        case .female:
            switch answers["periods"] {
            case "established": return .late
            case "recent": return .middle
            case "no": return signs >= 2 || answers["spurt"] == "yes" ? .early : (signs == 0 && unsureCount < 2 ? .notStarted : .early)
            default: break
            }
        case .male:
            switch answers["voice"] {
            case "settled": return .late
            case "changing": return .middle
            case "no": return signs >= 2 || answers["spurt"] == "yes" ? .early : (signs == 0 && unsureCount < 2 ? .notStarted : .early)
            default: break
            }
        }
        if unsureCount >= 3 { return .unsure }
        return signs >= 2 ? .early : .unsure
    }

    public static func title(_ stage: PubertyStage) -> String {
        switch stage {
        case .notStarted: return "Before puberty"
        case .early: return "Early puberty"
        case .middle: return "Middle of puberty"
        case .late: return "Later puberty"
        case .unsure: return "Hard to tell yet"
        }
    }

    /// What the stage usually means for growth, in plain words. Ranges are typical, not personal predictions.
    public static func explanation(_ stage: PubertyStage, sex: GrowthChartSex) -> String {
        switch (stage, sex) {
        case (.notStarted, _):
            return "Growth is usually steady before puberty, about 5–6 cm a year. The biggest growth spurt is still ahead."
        case (.early, .female):
            return "The fastest growth for girls usually comes early in puberty, often in the year or so before periods start."
        case (.early, .male):
            return "Boys usually reach their fastest growth a little later in puberty, so the biggest spurt may still be coming."
        case (.middle, .female):
            return "The fastest growth has usually passed by the time periods start. On average girls grow about 5–7 cm more over the next one to two years."
        case (.middle, .male):
            return "Many boys are near their fastest growth while their voice is changing. Growth usually continues for a couple of years after."
        case (.late, .female):
            return "Growth usually slows a lot one to two years after periods start, and most girls are close to adult height."
        case (.late, .male):
            return "Growth usually slows once the voice has settled, though some boys keep growing slowly into their late teens."
        case (.unsure, _):
            return "That's completely normal. Measuring every three months shows growth speed, which is the clearest sign of where growth is."
        }
    }

    public static let disclaimer = "A rough guide from a few everyday signs, not a medical assessment. A doctor can tell you more."
}
