import Foundation

/// Deterministic answers for common questions, built only from `AssistantFacts`. Used on iPhones without
/// Apple Intelligence, when the model is unavailable, and whenever a model answer fails the output guard.
public enum AssistantGuide {
    public enum Intent: String, CaseIterable, Sendable {
        case estimate, percentile, speed, taller, support, sleep, nutrition, exercise, measuring, stopGrowing, doctor, report, summary
    }

    static let keywords: [(Intent, [String])] = [
        (.estimate, ["how tall will", "how tall might", "how tall would", "adult height", "final height", "predict", "end up", "grown-up height", "estimate"]),
        (.stopGrowing, ["stop growing", "growth plate", "done growing", "finish growing", "still grow", "when will i stop", "until what age"]),
        (.taller, ["grow taller", "get taller", "be taller", "increase height", "increase my height", "boost", "stretch", "hang", "taller faster"]),
        (.support, ["support", "help her grow", "help him grow", "help them grow", "help my child", "healthy growth", "what can i do", "what can we do"]),
        (.percentile, ["percentile", "normal", "average", "short for", "tall for", "compared", "behind", "on track"]),
        (.speed, ["growth spurt", "spurt", "speed", "velocity", "how fast", "how much did", "how much have", "stopped growing", "slowed"]),
        (.sleep, ["sleep", "bedtime", "nap", "rest"]),
        (.nutrition, ["eat", "food", "protein", "milk", "diet", "nutrition", "vitamin", "meal"]),
        (.exercise, ["exercise", "sport", "basketball", "swim", "gym", "workout", "yoga", "lifting", "weights"]),
        (.measuring, ["measure", "accurate", "accuracy", "how often", "next measurement", "time of day"]),
        (.doctor, ["doctor", "worried", "worry", "concern", "pediatrician", "paediatrician", "problem", "wrong"]),
        (.report, ["report", "pdf", "share with"])
    ]

    public static func intent(for question: String) -> Intent {
        let text = question.lowercased()
        return keywords.first { $0.1.contains(where: text.contains) }?.0 ?? .summary
    }

    public static func answer(_ question: String, facts f: AssistantFacts) -> String {
        let whose = f.possessive
        let Whose = whose.prefix(1).uppercased() + whose.dropFirst()
        switch intent(for: question) {
        case .estimate:
            if let range = f.estimateRange, let sentence = f.estimateSentence, let level = f.estimateUncertainty {
                return "\(sentence.replacingOccurrences(of: "in this range", with: "about \(range)")) That's a \(level), based on the CDC growth chart. It's an estimate, not a guarantee: puberty timing can move it, so measuring every few months keeps it current."
            }
            return f.estimateUnavailable ?? "An adult-height estimate isn't available for this profile yet. A careful measurement helps."
        case .percentile:
            guard let ordinal = f.percentileOrdinal, let value = f.percentileValue, let height = f.heightText else {
                return "Percentiles come from the CDC growth chart, which covers ages 2 to 20, so there isn't one for this profile."
            }
            return "\(Whose) latest height, \(height), is at about the \(ordinal) percentile: of 100 people the same age and sex, about \(value) are shorter. Anywhere from the 3rd to the 97th is within the typical range on the chart. The pattern over several measurements says more than any single number."
        case .speed:
            if let speed = f.speedText {
                return "\(Whose) recent growth speed is \(speed). Speed changes a lot with age and puberty, and home measurements vary a little, so it's most useful across 6 to 12 months."
            }
            return f.speedUnavailable ?? "Growth speed isn't available yet."
        case .taller:
            return "Honestly: no food, stretch, pill or exercise adds height beyond what genes allow, and anything promising that isn't telling the truth. What does help growth reach its natural potential is enough sleep, regular balanced meals and being active. " + (f.weekText.map { "This week: \($0)" } ?? "")
        case .support:
            var text = "The things that help growth reach its natural potential are simple: enough sleep on a steady schedule, regular balanced meals, and being active most days. Measuring every few months, the same way each time, keeps the picture clear."
            if let week = f.weekText { text += " This week: \(week)" }
            if let habit = f.mostConsistentHabit { text += " Most consistent so far: \(habit.lowercased())." }
            return text
        case .sleep:
            return "Sleep supports healthy growth and how you feel day to day. Common guidance is about 9 to 12 hours a night for ages 6 to 12 and 8 to 10 hours for teenagers. A steady bedtime and wake time, even on weekends, usually helps more than one big change."
        case .nutrition:
            return "Regular meals with a variety of foods support growth: protein, dairy or other calcium sources, whole grains, fruit and vegetables. No single food makes anyone taller, and this app never suggests diets or calorie targets for young people. A doctor can help if you're worried about eating."
        case .exercise:
            return "Being active is great for bones, muscles and mood. No sport adds height, including basketball or swimming; tall people are often drawn to those sports rather than made tall by them. Pick activities you enjoy and can keep doing."
        case .measuring:
            return "For the clearest picture, measure every few months rather than often: same time of day (mornings are best, since height drops a little during the day), shoes off, heels, back and head against a wall. " + (f.nextMeasurementText ?? "")
        case .stopGrowing:
            var text = "Most growth finishes after puberty, often in the mid-teens for girls and the later teens for boys, with a lot of variation between people. Growth speed is the best clue: once it drops below about 1 cm a year, most growth is done."
            if let speed = f.speedText { text += " \(Whose) recent speed is \(speed)." }
            return text
        case .doctor:
            var text = "If you're worried, a pediatrician can look at these measurements in context, and the doctor-ready report puts them in one place. People often check in when height is below the 3rd or above the 97th percentile, crosses percentile lines downward, or seems to stop early."
            if !f.concernSignposts.isEmpty { text += " Here: " + f.concernSignposts.joined(separator: " ") }
            return text
        case .report:
            return "The doctor-ready report is a PDF with the growth chart, every measurement, percentile history, growth speed, methods and limitations. It's made on this iPhone and nothing is uploaded. Find it in Profile › Doctor-ready report, or at the bottom of the Growth tab."
        case .summary:
            var parts: [String] = []
            if let height = f.heightText, let ordinal = f.percentileOrdinal {
                parts.append("\(Whose) latest height is \(height), around the \(ordinal) percentile.")
            } else if let height = f.heightText {
                parts.append("\(Whose) latest height is \(height).")
            }
            if let speed = f.speedText { parts.append("Recent growth speed: \(speed).") }
            if let range = f.estimateRange { parts.append("Adult-height estimate: \(range), not a guarantee.") }
            parts.append("You can ask about the estimate, percentiles, growth speed, sleep, food, activity, measuring or when growth usually stops.")
            return parts.joined(separator: " ")
        }
    }

    public static func suggestions(for f: AssistantFacts) -> [String] {
        let child = f.isChildProfile
        let name = f.subjectName
        var list: [String] = []
        if f.estimateRange != nil { list.append(child ? "How tall might \(name) be as an adult?" : "How tall might I be as an adult?") }
        if f.percentileOrdinal != nil { list.append(child ? "Is \(name)'s growth on track?" : "Is my growth on track?") }
        list.append(child ? "How can I support \(name)'s growth?" : "Can anything make me taller?")
        if f.stillGrowing { list.append(child ? "When will \(name) stop growing?" : "When will I stop growing?") }
        if f.speedText != nil { list.append(child ? "How fast is \(name) growing?" : "How fast am I growing?") }
        list.append(child ? "When should we measure next?" : "When should I measure next?")
        return Array(list.prefix(5))
    }
}

/// Instructions for the on-device model. The facts brief is the only source of numbers.
public enum AssistantPrompt {
    public static func instructions(facts: AssistantFacts) -> String {
        """
        You are \(BrandConfig.current.assistantName), a calm, friendly guide inside a growth-tracking app. \
        \(facts.isChildProfile ? "You are talking to a parent or caregiver about their child." : "You are talking to the person whose growth this is; they may be a teenager.")

        FACTS (the only numbers you may use):
        \(facts.brief)

        RULES:
        - Use only the numbers in FACTS. Never invent, calculate or round a height, percentile or estimate.
        - Never promise or predict an exact adult height. Call the estimate an estimate, not a guarantee.
        - Do not diagnose. For worries, suggest talking with a pediatrician or doctor.
        - Never recommend medicines, hormones, supplements, surgery, diets or calorie targets.
        - Sleep, food and activity support healthy growth but do not add height beyond genetics. Say so honestly.
        - Be warm, plain and short: at most 4 sentences. No lists, no headings.
        - If a question is not about growth, height, measuring or healthy habits, say briefly that you can only help with those.
        """
    }
}
