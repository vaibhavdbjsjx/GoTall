import Foundation

/// A person whose growth is tracked.
///
/// Evolution rule: new fields must be optional or have defaults and be decoded with
/// `decodeIfPresent`, so older files always load (no destructive migrations).
/// Bump `currentSchemaVersion` only when a value's *meaning* changes, and add a step to `SnapshotMigrator`.
public struct GrowthProfile: Codable, Identifiable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var id: UUID
    public var subject: ProfileSubject
    /// Optional nickname for child profiles ("Maya"). Not required; never sent anywhere.
    public var nickname: String?
    public var birthDate: Date
    public var chartSex: GrowthChartSex
    public var unitPreference: HeightUnit
    public var measurements: [HeightMeasurement]
    public var parentHeights: ParentHeights
    public var recentGrowthChange: RecentGrowthChange?
    public var sleep: SleepBaseline
    public var activity: ActivityBaseline
    public var nutrition: NutritionBaseline
    /// Ordered by the order the person selected them; the first is treated as primary.
    public var goals: [Goal]
    public var intent: UserIntent?
    /// Daily habit check-ins (Phase 4). One entry per day with at least one completed habit.
    public var habitLog: [HabitDay]
    /// Habits the person chose to track. `nil` = defaults chosen from goals.
    public var activeHabits: [HabitKind]?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        subject: ProfileSubject,
        nickname: String? = nil,
        birthDate: Date,
        chartSex: GrowthChartSex,
        unitPreference: HeightUnit,
        measurements: [HeightMeasurement],
        parentHeights: ParentHeights = ParentHeights(),
        recentGrowthChange: RecentGrowthChange? = nil,
        sleep: SleepBaseline = SleepBaseline(),
        activity: ActivityBaseline = ActivityBaseline(),
        nutrition: NutritionBaseline = NutritionBaseline(),
        goals: [Goal] = [],
        intent: UserIntent? = nil,
        habitLog: [HabitDay] = [],
        activeHabits: [HabitKind]? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.id = id
        self.subject = subject
        self.nickname = nickname
        self.birthDate = birthDate
        self.chartSex = chartSex
        self.unitPreference = unitPreference
        self.measurements = measurements.sorted { $0.date < $1.date }
        self.parentHeights = parentHeights
        self.recentGrowthChange = recentGrowthChange
        self.sleep = sleep
        self.activity = activity
        self.nutrition = nutrition
        self.goals = goals
        self.intent = intent
        self.habitLog = habitLog
        self.activeHabits = activeHabits
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var sortedMeasurements: [HeightMeasurement] { measurements.sorted { $0.date < $1.date } }
    public var latestMeasurement: HeightMeasurement? { sortedMeasurements.last }
    public var primaryGoal: Goal? { goals.first }

    public func age(on date: Date, calendar: Calendar) -> Age? {
        AgeCalculator.age(birthDate: birthDate, on: date, calendar: calendar)
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, id, subject, nickname, birthDate, chartSex, unitPreference, measurements,
             parentHeights, recentGrowthChange, sleep, activity, nutrition, goals, intent, habitLog, activeHabits, createdAt, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        id = try c.decode(UUID.self, forKey: .id)
        subject = try c.decode(ProfileSubject.self, forKey: .subject)
        nickname = try c.decodeIfPresent(String.self, forKey: .nickname)
        birthDate = try c.decode(Date.self, forKey: .birthDate)
        chartSex = try c.decode(GrowthChartSex.self, forKey: .chartSex)
        unitPreference = try c.decodeIfPresent(HeightUnit.self, forKey: .unitPreference) ?? .centimeters
        measurements = try c.decodeIfPresent([HeightMeasurement].self, forKey: .measurements) ?? []
        parentHeights = try c.decodeIfPresent(ParentHeights.self, forKey: .parentHeights) ?? ParentHeights()
        recentGrowthChange = try c.decodeIfPresent(RecentGrowthChange.self, forKey: .recentGrowthChange)
        sleep = try c.decodeIfPresent(SleepBaseline.self, forKey: .sleep) ?? SleepBaseline()
        activity = try c.decodeIfPresent(ActivityBaseline.self, forKey: .activity) ?? ActivityBaseline()
        nutrition = try c.decodeIfPresent(NutritionBaseline.self, forKey: .nutrition) ?? NutritionBaseline()
        goals = try c.decodeIfPresent([Goal].self, forKey: .goals) ?? []
        intent = try c.decodeIfPresent(UserIntent.self, forKey: .intent)
        habitLog = try c.decodeIfPresent([HabitDay].self, forKey: .habitLog) ?? []
        activeHabits = try c.decodeIfPresent([HabitKind].self, forKey: .activeHabits)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(timeIntervalSince1970: 0)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}

public struct PrivacyAcknowledgement: Codable, Hashable, Sendable {
    /// Bump when the privacy explanation materially changes; users re-acknowledge.
    public static let currentVersion = 1
    public var version: Int
    public var acknowledgedAt: Date

    public init(version: Int = PrivacyAcknowledgement.currentVersion, acknowledgedAt: Date) {
        self.version = version
        self.acknowledgedAt = acknowledgedAt
    }
}

/// Everything persisted on device.
public struct AppSnapshot: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var profiles: [GrowthProfile]
    public var activeProfileID: UUID?
    public var onboardingDraft: OnboardingDraft?
    public var privacyAcknowledgement: PrivacyAcknowledgement?
    /// Device-wide reminder choices (Phase 4). Scheduling arrives later; choices are kept now.
    public var notificationPreferences: NotificationPreferences

    public init(profiles: [GrowthProfile] = [], activeProfileID: UUID? = nil, onboardingDraft: OnboardingDraft? = nil, privacyAcknowledgement: PrivacyAcknowledgement? = nil) {
        self.schemaVersion = Self.currentSchemaVersion
        self.profiles = profiles
        self.activeProfileID = activeProfileID
        self.onboardingDraft = onboardingDraft
        self.privacyAcknowledgement = privacyAcknowledgement
        self.notificationPreferences = NotificationPreferences()
    }

    public static let empty = AppSnapshot()

    public var activeProfile: GrowthProfile? {
        profiles.first { $0.id == activeProfileID } ?? profiles.first
    }

    public var hasCompletedOnboarding: Bool { !profiles.isEmpty }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, profiles, activeProfileID, onboardingDraft, privacyAcknowledgement, notificationPreferences
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        profiles = try c.decodeIfPresent([GrowthProfile].self, forKey: .profiles) ?? []
        activeProfileID = try c.decodeIfPresent(UUID.self, forKey: .activeProfileID)
        onboardingDraft = try c.decodeIfPresent(OnboardingDraft.self, forKey: .onboardingDraft)
        privacyAcknowledgement = try c.decodeIfPresent(PrivacyAcknowledgement.self, forKey: .privacyAcknowledgement)
        notificationPreferences = try c.decodeIfPresent(NotificationPreferences.self, forKey: .notificationPreferences) ?? NotificationPreferences()
    }
}
