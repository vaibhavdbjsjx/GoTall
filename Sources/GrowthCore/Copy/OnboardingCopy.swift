import Foundation

/// All onboarding copy, adapted to who the profile is for and their age.
/// Lives in the core so wording rules (parent vs. self, adult vs. growing) are unit-tested.
/// Banned phrases are checked by `CopyGuard` in tests.
public struct OnboardingCopy: Sendable {
    public var draft: OnboardingDraft
    public var ageBand: AgeBand?

    public init(draft: OnboardingDraft, ageBand: AgeBand?) {
        self.draft = draft
        self.ageBand = ageBand
    }

    var isChild: Bool { draft.subject == .child }
    var name: String { draft.displayName(fallback: "your child") }
    var Name: String { draft.displayName(fallback: "Your child") }
    /// "your" / "Maya's"
    var possessive: String { isChild ? possessiveForm(name) : "your" }
    var isAdult: Bool { ageBand == .adult || ageBand == .youngAdult }

    func possessiveForm(_ value: String) -> String {
        if value == "your child" { return "your child's" }
        return value.hasSuffix("s") ? value + "’" : value + "’s"
    }

    // MARK: Introduction

    public struct ValuePoint: Sendable, Hashable {
        public var symbol: String
        public var title: String
        public var detail: String
    }

    public var welcomeTitle: String { "Growth, made clear." }
    public var welcomeSubtitle: String {
        "Track height over time, see it on real growth charts and build healthy routines, with honest estimates instead of promises."
    }
    public var welcomePoints: [ValuePoint] {
        [
            ValuePoint(symbol: "ruler", title: "A record that lasts", detail: "Log measurements and watch the trend build over months and years."),
            ValuePoint(symbol: "chart.xyaxis.line", title: "Real reference charts", detail: "See where height sits on CDC growth charts, explained in plain language."),
            ValuePoint(symbol: "scope", title: "Honest about uncertainty", detail: "Estimates come as ranges with the method shown. Nobody can promise an exact height."),
            ValuePoint(symbol: "lock.shield", title: "Private by design", detail: "Your answers stay on this device.")
        ]
    }
    public var welcomeAction: String { "Get started" }

    public var privacyTitle: String { "Your data stays yours." }
    public var privacyPoints: [ValuePoint] {
        [
            ValuePoint(symbol: "iphone", title: "Stored on this device", detail: "We don't run servers that hold your answers."),
            ValuePoint(symbol: "hand.raised", title: "No ads, no tracking", detail: "Nothing is sold, shared or used to follow you across apps."),
            ValuePoint(symbol: "list.bullet.clipboard", title: "Only what's needed", detail: "Each question explains why we ask. Most are optional."),
            ValuePoint(symbol: "trash", title: "Delete anytime", detail: "Remove everything from Profile in two taps.")
        ]
    }
    public var medicalNote: String {
        "This app helps you track and understand growth. It doesn't diagnose anything. For health concerns, talk to a doctor."
    }
    public var privacyAction: String { "I understand" }

    // MARK: Profile

    public var subjectTitle: String { "Who is this profile for?" }
    public var subjectFooter: String { "Parents can add more children later." }

    public var nicknameTitle: String { "What should we call your child?" }
    public var nicknameSubtitle: String { "A first name or nickname is enough. It only labels the profile on this device." }

    public var birthDateTitle: String { isChild ? "When was \(name) born?" : "When were you born?" }
    public var birthDateSubtitle: String {
        "Age decides which growth chart applies and which questions are relevant. We'll work it out from the date."
    }

    public func birthDateMessage(_ validation: BirthDateValidation) -> String? {
        switch validation {
        case .valid(let age): return "Age \(age.years) years, \(age.months) \(age.months == 1 ? "month" : "months")"
        case .missing: return nil
        case .inFuture: return "That date is in the future."
        case .implausiblyOld: return "Please check the year. That's more than 100 years ago."
        case .tooYoung: return "This app is designed for ages 2 and up, because the growth charts it uses start at age 2."
        case .needsGuardian: return "For anyone under 13, a parent or guardian sets up and manages the profile."
        }
    }
    public var guardianHandoffAction: String { "I'm a parent or guardian" }

    public var chartSexTitle: String { "Which growth chart should we use?" }
    public var chartSexSubtitle: String {
        "Growth charts are published separately by sex at birth, because growth patterns differ, especially around puberty."
    }
    public var chartSexHelpTitle: String { "Why only two options?" }
    public var chartSexHelp: String {
        "Reference growth charts are built from population data recorded by sex at birth. This choice only selects a chart; it isn't a question about identity. If puberty-affecting treatment is part of \(possessive) care, growth charts may not apply, so follow the clinician's guidance."
    }

    public var heightTitle: String { isChild ? "How tall is \(name) now?" : "How tall are you now?" }
    public var heightSubtitle: String { "Use a recent measurement if you can. A careful measurement beats a guess." }
    public var heightMethodLabel: String { "How was this measured?" }
    public var measuringGuideLink: String { "How to measure accurately" }

    public func heightMessage(_ result: HeightValidation.Result) -> String? {
        switch result {
        case .valid, .missing: return nil
        case .tooShort: return "That looks too short. Check the number and the unit."
        case .tooTall: return "That looks too tall. Check the number and the unit."
        }
    }

    public var measuringGuideTitle: String { "Measuring at home" }
    public var measuringGuideSteps: [String] {
        [
            "Shoes off, hair flat. Stand on a hard floor, not carpet.",
            "Back to a wall: heels, bottom and shoulders touching it.",
            "Look straight ahead with the chin level.",
            "Rest a book flat on top of the head, square to the wall, and mark underneath it.",
            "Measure from the floor to the mark. Repeat once and use the average."
        ]
    }
    public var measuringGuideTip: String {
        "Measure at the same time of day each time. Most people are slightly taller in the morning than in the evening."
    }

    // MARK: Growth

    public var parentHeightsTitle: String { "How tall are \(isChild ? possessiveForm(name) : "your") biological parents?" }
    public var parentHeightsSubtitle: String {
        "Height runs in families, so this adds useful context. It describes a family range, not a promise of adult height."
    }
    public var motherLabel: String { "Biological mother" }
    public var fatherLabel: String { "Biological father" }
    public var parentUnknownLabel: String { "Don't know or prefer not to say" }
    public var parentHeightsFooter: String {
        "Adopted, donor-conceived or not sure? Choose \"Don't know\". Everything else still works."
    }

    public var historyQuestionTitle: String { "Any earlier measurements?" }
    public var historyQuestionSubtitle: String {
        "Heights from doctor visits, school records or a marked door frame show growth over time from day one."
    }
    public var historyYes: String { "Yes, I have some" }
    public var historyNo: String { "Not right now" }
    public var historyQuestionFooter: String { "You can always add them later." }

    public var historyEntryTitle: String { "Add earlier measurements" }
    public var historyEntrySubtitle: String { "Add as many as you have. Approximate dates are fine." }
    public var historyAddAction: String { "Add a measurement" }

    public func historyIssueMessage(_ issue: HistoryEntryIssue) -> String {
        switch issue {
        case .missingDate: return "Add a date."
        case .missingHeight: return "Add a height."
        case .heightOutOfRange: return "Check this height and its unit."
        case .dateBeforeBirth: return "This date is before the birth date."
        case .dateInFuture: return "This date is in the future."
        case .dateNotBeforeCurrentMeasurement: return "This is the same day as the current height. Pick an earlier date."
        case .duplicateDate: return "There's already a measurement on this day."
        }
    }
    public var historyTallerWarning: String { "This is taller than the current height. Worth a quick double-check." }

    public var growthChangeTitle: String { isChild ? "Has \(possessiveForm(name)) growth changed recently?" : "Has your growth changed recently?" }
    public var growthChangeSubtitle: String {
        "Think about the past year or so. This helps explain the trend as measurements come in. It doesn't change any estimate."
    }

    // MARK: Lifestyle

    public var sleepTitle: String {
        if isAdult { return "What does a typical weeknight look like?" }
        return isChild ? "What does a school night look like for \(name)?" : "What does a typical school night look like?"
    }
    public var sleepSubtitle: String { "A starting point for a steady routine. Good sleep supports overall health and recovery." }
    public var bedtimeLabel: String { "Usually asleep by" }
    public var wakeLabel: String { "Usually wakes at" }
    public var sleepConsistencyLabel: String { "And on weekends?" }

    public var activityTitle: String { isChild ? "How active is \(possessiveForm(name)) typical week?" : "How active is a typical week?" }
    public var activitySubtitle: String { "Used to suggest realistic routines, not to judge." }
    public var activityFrequencyLabel: String { "Sport or exercise sessions per week" }
    public var activityPreferredLabel: String { "Activities \(isChild ? "they enjoy" : "you enjoy")" }

    public var nutritionTitle: String { isChild ? "How do meals usually go for \(name)?" : "How do meals usually go?" }
    public var nutritionSubtitle: String { "Just the big picture, so food suggestions fit. No calorie counting, ever." }
    public var mealRegularityLabel: String { "Meals" }
    public var dietaryPatternLabel: String { "Eating pattern" }
    public var eatingChallengesLabel: String { "Anything that applies?" }
    public var hydrationLabel: String { "Usual drinks" }

    // MARK: Goals

    public var goalsTitle: String { "What would be most useful?" }
    public var goalsSubtitle: String { "Pick any. Your home screen will put these first." }
    public var availableGoals: [Goal] {
        isAdult && ageBand == .adult ? Goal.allCases.filter { !$0.requiresGrowingAge } : Goal.allCases
    }

    public var intentTitle: String { "What brings you here?" }
    public var intentSubtitle: String { "There's no wrong answer. It helps us set the right tone." }

    public var concernTitle: String { "Thanks for telling us." }
    /// Draft safety copy. Requires medical-reviewer approval before release (see docs/phase-2-foundation.md).
    public var concernBody: [String] {
        if ageBand == .adult {
            return [
                "For most adults, height stops changing once growth has finished in the late teens or early twenties.",
                "If you've noticed a change in your height, or something about it worries you, a doctor is the right person to talk to.",
                "This app can keep a clear record of measurements to bring along."
            ]
        }
        let subject = isChild ? "children" : "people"
        return [
            "Many height worries turn out to be normal variation. \(subject.capitalized) grow at different times and speeds, especially around puberty.",
            "If you're concerned, a doctor can measure accurately, look at growth over time and check whether anything needs attention.",
            "A clear record of measurements makes that conversation easier, and keeping one is exactly what this app is for."
        ]
    }
    public var concernAction: String { "Continue" }

    // MARK: Personalisation

    public var buildingTitle: String { "Putting your growth profile together" }
    public var summaryTitle: String { isChild ? "\(possessiveForm(Name)) growth profile" : "Your growth profile" }
    public var summarySubtitle: String { "Check everything looks right. Tap any section to change it." }
    public var finishAction: String { "Start tracking" }
}

/// Phrases that must never appear in product copy (docs/scientific-prediction-review.md §6.2).
public enum CopyGuard {
    public static let bannedPhrases = [
        "guarantee", "unlock your", "become taller", "maximum height", "max height", "add cm", "grow taller",
        "% accurate", "ai knows", "you will reach", "boost growth hormone", "hgh", "increase your height", "true height"
    ]

    /// Negated forms that are required honesty wording, removed before matching.
    public static let allowedPhrases = ["not a guarantee", "no guarantee"]

    public static func violations(in text: String) -> [String] {
        var lowered = text.lowercased()
        for allowed in allowedPhrases { lowered = lowered.replacingOccurrences(of: allowed, with: "") }
        return bannedPhrases.filter { lowered.contains($0) }
    }
}
