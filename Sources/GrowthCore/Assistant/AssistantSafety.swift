import Foundation

/// Questions that must not go to a language model get a fixed, reviewed answer instead.
public enum AssistantSafety {
    public enum Topic: String, Sendable, Equatable {
        case crisis, eatingDisorder, emergency, harmfulGrowthMethod
    }

    public enum Outcome: Sendable, Equatable {
        case allowed
        case fixed(Topic, String)
    }

    static let crisis = ["kill myself", "suicide", "suicidal", "self harm", "self-harm", "hurt myself", "want to die", "end my life", "cut myself"]
    static let eating = ["stop eating", "starve", "starving myself", "not eating", "purge", "throw up after", "make myself sick", "lose weight fast", "skip meals to", "too fat"]
    static let emergency = ["chest pain", "can't breathe", "cannot breathe", "passed out", "unconscious", "overdose", "seizure"]
    static let harmful = ["hgh", "growth hormone", "steroid", "pill to grow", "pills to grow", "supplement to grow", "supplements to grow",
                          "height pill", "height supplement", "limb lengthening", "leg lengthening", "surgery to be taller", "surgery to get taller", "injection to grow"]

    public static func classify(_ question: String) -> Outcome {
        let text = question.lowercased()
        if crisis.contains(where: text.contains) {
            return .fixed(.crisis, "I'm really glad you said something. You deserve support right now. Please talk to someone you trust, like a parent, family member, teacher or doctor. In the US you can call or text 988 to reach the Suicide & Crisis Lifeline any time. If you might be in immediate danger, call 911.")
        }
        if emergency.contains(where: text.contains) {
            return .fixed(.emergency, "That sounds like it needs help right away. If this is happening now, call 911 (or your local emergency number). This app can't help with emergencies.")
        }
        if eating.contains(where: text.contains) {
            return .fixed(.eatingDisorder, "It sounds like food or body worries might be weighing on you. That's worth talking about with someone you trust, like a parent or a doctor. Eating less doesn't help growth; regular meals support it. In the US you can also call or text 988 if you're struggling.")
        }
        if harmful.contains(where: text.contains) {
            return .fixed(.harmfulGrowthMethod, "Growth hormone, steroids, height pills or supplements and surgery aren't ways to get taller for healthy people, and some carry real risks. Growth hormone is only prescribed by specialists for diagnosed conditions. If you're worried about growth, a pediatrician can look at the measurements in context. The doctor-ready report puts them all in one place.")
        }
        return .allowed
    }
}

/// Checks a model answer before it's shown. Rejects answers that invent heights or percentiles, make
/// guarantees, give medical or dosing advice, or use any banned growth claim. Rejected answers are replaced
/// by the built-in guide, which only uses engine numbers.
public enum AssistantOutputGuard {
    public static let maximumLength = 1_400

    static let banned = ["hgh", "growth hormone", "steroid", "dosage", " dose", " mg ", "milligram", "limb lengthening", "you will be ",
                         "you'll be ", "will definitely", "guaranteed", "calorie", "diet plan", "lose weight", "stretches to grow",
                         "exercises to grow taller", "make you taller", "makes you taller", "add inches", "add centimeters", "add centimetres"]
    static let allowedPhrases = ["not a diagnosis", "can't diagnose", "cannot diagnose", "doesn't diagnose", "does not diagnose",
                                 "won't make you taller", "will not make you taller", "doesn't make you taller", "don't make you taller",
                                 "can't make you taller", "cannot make you taller", "no exercise makes you taller", "nothing makes you taller",
                                 "never suggests diets or calorie targets", "no diets or calorie targets"]

    public enum Rejection: Sendable, Equatable {
        case empty, tooLong, bannedPhrase(String), inventedNumber(String)
    }

    public static func check(_ answer: String, brief: String) -> Rejection? {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .empty }
        if trimmed.count > maximumLength { return .tooLong }
        var lowered = " " + trimmed.lowercased() + " "
        for phrase in allowedPhrases { lowered = lowered.replacingOccurrences(of: phrase, with: "") }
        if let violation = CopyGuard.violations(in: lowered).first { return .bannedPhrase(violation) }
        if let phrase = banned.first(where: lowered.contains) { return .bannedPhrase(phrase.trimmingCharacters(in: .whitespaces)) }

        let allowed = numbers(in: brief)
        for value in measuredNumbers(in: trimmed) where !allowed.contains(where: { abs($0 - value) < 0.051 }) {
            return .inventedNumber(String(value))
        }
        return nil
    }

    static func numbers(in text: String) -> [Double] {
        matches(#"\d+(?:\.\d+)?"#, in: text).compactMap { Double($0.first ?? "") }
    }

    /// Numbers attached to a height unit or written as a percentile ordinal.
    static func measuredNumbers(in text: String) -> [Double] {
        let lowered = text.lowercased()
        var values: [Double] = []
        let unit = #"\s*(?:cm\b|centimet|in\b|inch|ft\b|feet|foot|′|″|'|")"#
        for m in matches(#"(\d+(?:\.\d+)?)\s*[–-]\s*(\d+(?:\.\d+)?)"# + unit, in: lowered) {
            values += m.dropFirst().compactMap(Double.init)
        }
        for m in matches(#"(\d+(?:\.\d+)?)"# + unit, in: lowered) { values += m.dropFirst().compactMap(Double.init) }
        for m in matches(#"\b(\d{1,2})(?:st|nd|rd|th)\b"#, in: lowered) { values += m.dropFirst().compactMap(Double.init) }
        return values
    }

    static func matches(_ pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { result in
            (0..<result.numberOfRanges).map { i in
                let r = result.range(at: i)
                return r.location == NSNotFound ? "" : ns.substring(with: r)
            }
        }
    }
}
