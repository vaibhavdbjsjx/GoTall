import Foundation

public enum OnboardingMode: String, Codable, Sendable {
    /// First launch: includes welcome and privacy.
    case firstRun
    /// Adding another (child) profile later: skips introduction and the subject question.
    case additionalProfile
}

/// In-progress answers. Persisted after every change so nothing is lost if the app is closed or killed.
/// All fields are optional; `ProfileBuilder` turns a complete draft into a `GrowthProfile`,
/// keeping only answers to questions that are visible for the final set of answers.
public struct OnboardingDraft: Codable, Hashable, Sendable {
    public var mode: OnboardingMode
    public var currentStep: OnboardingStep
    /// Set when the person jumps back from the summary to edit an answer.
    public var editingFromSummary: Bool

    public var privacyAcknowledged: Bool
    public var subject: ProfileSubject?
    public var nickname: String?
    public var birthDate: Date?
    public var chartSex: GrowthChartSex?
    public var unit: HeightUnit
    public var currentHeightCm: Double?
    public var currentHeightMethod: MeasurementMethod
    /// Date the current height applies to. Fixed when height is first entered, so resuming
    /// onboarding on a later day doesn't silently move the measurement date.
    public var currentHeightDate: Date?
    public var mother: ParentHeightAnswer?
    public var father: ParentHeightAnswer?
    public var hasHistory: Bool?
    public var history: [HistoryEntryDraft]
    public var recentGrowthChange: RecentGrowthChange?
    public var sleep: SleepBaseline
    public var activity: ActivityBaseline
    public var nutrition: NutritionBaseline
    public var goals: [Goal]
    public var intent: UserIntent?
    public var startedAt: Date
    public var updatedAt: Date

    public init(mode: OnboardingMode, startedAt: Date, unit: HeightUnit = .centimeters) {
        self.mode = mode
        self.currentStep = mode == .firstRun ? .welcome : .nickname
        self.editingFromSummary = false
        self.privacyAcknowledged = mode == .additionalProfile
        self.subject = mode == .additionalProfile ? .child : nil
        self.unit = unit
        self.currentHeightMethod = .home
        self.history = []
        self.sleep = SleepBaseline()
        self.activity = ActivityBaseline()
        self.nutrition = NutritionBaseline()
        self.goals = []
        self.startedAt = startedAt
        self.updatedAt = startedAt
    }

    enum CodingKeys: String, CodingKey {
        case mode, currentStep, editingFromSummary, privacyAcknowledged, subject, nickname, birthDate, chartSex, unit,
             currentHeightCm, currentHeightMethod, currentHeightDate, mother, father, hasHistory, history,
             recentGrowthChange, sleep, activity, nutrition, goals, intent, startedAt, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mode = try c.decodeIfPresent(OnboardingMode.self, forKey: .mode) ?? .firstRun
        // An unknown step name (e.g. removed in a later version) restarts at the first step rather than failing.
        let stepName = try c.decodeIfPresent(String.self, forKey: .currentStep)
        currentStep = stepName.flatMap(OnboardingStep.init(rawValue:)) ?? (mode == .firstRun ? .welcome : .nickname)
        editingFromSummary = try c.decodeIfPresent(Bool.self, forKey: .editingFromSummary) ?? false
        privacyAcknowledged = try c.decodeIfPresent(Bool.self, forKey: .privacyAcknowledged) ?? false
        subject = try c.decodeIfPresent(ProfileSubject.self, forKey: .subject)
        nickname = try c.decodeIfPresent(String.self, forKey: .nickname)
        birthDate = try c.decodeIfPresent(Date.self, forKey: .birthDate)
        chartSex = try c.decodeIfPresent(GrowthChartSex.self, forKey: .chartSex)
        unit = try c.decodeIfPresent(HeightUnit.self, forKey: .unit) ?? .centimeters
        currentHeightCm = try c.decodeIfPresent(Double.self, forKey: .currentHeightCm)
        currentHeightMethod = try c.decodeIfPresent(MeasurementMethod.self, forKey: .currentHeightMethod) ?? .home
        currentHeightDate = try c.decodeIfPresent(Date.self, forKey: .currentHeightDate)
        mother = try c.decodeIfPresent(ParentHeightAnswer.self, forKey: .mother)
        father = try c.decodeIfPresent(ParentHeightAnswer.self, forKey: .father)
        hasHistory = try c.decodeIfPresent(Bool.self, forKey: .hasHistory)
        history = try c.decodeIfPresent([HistoryEntryDraft].self, forKey: .history) ?? []
        recentGrowthChange = try c.decodeIfPresent(RecentGrowthChange.self, forKey: .recentGrowthChange)
        sleep = try c.decodeIfPresent(SleepBaseline.self, forKey: .sleep) ?? SleepBaseline()
        activity = try c.decodeIfPresent(ActivityBaseline.self, forKey: .activity) ?? ActivityBaseline()
        nutrition = try c.decodeIfPresent(NutritionBaseline.self, forKey: .nutrition) ?? NutritionBaseline()
        goals = try c.decodeIfPresent([Goal].self, forKey: .goals) ?? []
        intent = try c.decodeIfPresent(UserIntent.self, forKey: .intent)
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date(timeIntervalSince1970: 0)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? startedAt
    }

    public func displayName(fallback: String = "your child") -> String {
        let trimmed = nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }
}
