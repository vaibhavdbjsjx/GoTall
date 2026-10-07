import Foundation

/// Who the profile describes. The device owner is never stored as a profile unless `myself`;
/// a parent creating a child profile contributes no data about themselves.
public enum ProfileSubject: String, Codable, CaseIterable, Sendable {
    case myself
    case child
}

/// The growth-reference chart to use. Growth references (CDC/WHO) are published separately for
/// females and males, so this is the minimum input required to compute percentiles.
/// It is deliberately not a gender-identity field.
public enum GrowthChartSex: String, Codable, CaseIterable, Sendable {
    case female
    case male
}

public enum MeasurementMethod: String, Codable, CaseIterable, Sendable {
    /// Measured at home against a wall.
    case home
    /// Measured by a doctor, nurse or school.
    case professional
    /// A best guess. Lowers data quality; prompts a real measurement later.
    case estimate
}

public enum MeasurementOrigin: String, Codable, Sendable {
    case onboardingCurrent
    case onboardingHistory
    case manual
}

public struct HeightMeasurement: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var date: Date
    public var heightCm: Double
    public var method: MeasurementMethod
    public var origin: MeasurementOrigin

    public init(id: UUID = UUID(), date: Date, heightCm: Double, method: MeasurementMethod, origin: MeasurementOrigin) {
        self.id = id
        self.date = date
        self.heightCm = HeightConversion.rounded(heightCm)
        self.method = method
        self.origin = origin
    }
}

public enum ParentHeightSource: String, Codable, CaseIterable, Sendable {
    case measured
    case estimated
}

/// Answer for one biological parent. `nil` at the call site means "not asked / skipped".
public enum ParentHeightAnswer: Codable, Hashable, Sendable {
    case known(heightCm: Double, source: ParentHeightSource)
    /// "I don't know" or "Prefer not to say". Both are treated identically; no reason is stored.
    case unknown

    public var heightCm: Double? {
        if case .known(let cm, _) = self { return cm }
        return nil
    }
}

public struct ParentHeights: Codable, Hashable, Sendable {
    public var mother: ParentHeightAnswer?
    public var father: ParentHeightAnswer?

    public init(mother: ParentHeightAnswer? = nil, father: ParentHeightAnswer? = nil) {
        self.mother = mother
        self.father = father
    }

    public var bothKnown: Bool { mother?.heightCm != nil && father?.heightCm != nil }
}

public enum RecentGrowthChange: String, Codable, CaseIterable, Sendable {
    case faster
    case slower
    case aboutTheSame
    case notSure
}

public struct TimeOfDay: Codable, Hashable, Sendable, Comparable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    public var minutesSinceMidnight: Int { hour * 60 + minute }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }
}

public enum SleepConsistency: String, Codable, CaseIterable, Sendable {
    case similarEveryDay
    case laterOnWeekends
    case veryDifferent
}

public struct SleepBaseline: Codable, Hashable, Sendable {
    /// Usual bedtime on school or work nights.
    public var bedtime: TimeOfDay?
    /// Usual wake time on school or work days.
    public var wakeTime: TimeOfDay?
    public var consistency: SleepConsistency?

    public init(bedtime: TimeOfDay? = nil, wakeTime: TimeOfDay? = nil, consistency: SleepConsistency? = nil) {
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.consistency = consistency
    }

    /// Typical sleep opportunity derived from bedtime and wake time, handling midnight crossover.
    /// We derive duration instead of asking for it separately (one less question, no inconsistency).
    public var typicalDurationMinutes: Int? {
        guard let bedtime, let wakeTime else { return nil }
        var minutes = wakeTime.minutesSinceMidnight - bedtime.minutesSinceMidnight
        if minutes <= 0 { minutes += 24 * 60 }
        return minutes
    }

    public var isEmpty: Bool { bedtime == nil && wakeTime == nil && consistency == nil }
}

public enum ActivityLevel: String, Codable, CaseIterable, Sendable {
    case mostlySitting
    case lightlyActive
    case active
    case veryActive
}

public enum ExerciseFrequency: String, Codable, CaseIterable, Sendable {
    case rarely
    case oneToTwo
    case threeToFour
    case fivePlus
}

public enum ActivityType: String, Codable, CaseIterable, Sendable {
    case teamSports
    case running
    case swimming
    case cycling
    case strengthTraining
    case dance
    case martialArts
    case racketSports
    case walking
    case yogaMobility
    case other
}

public struct ActivityBaseline: Codable, Hashable, Sendable {
    public var level: ActivityLevel?
    public var frequency: ExerciseFrequency?
    public var preferred: [ActivityType]

    public init(level: ActivityLevel? = nil, frequency: ExerciseFrequency? = nil, preferred: [ActivityType] = []) {
        self.level = level
        self.frequency = frequency
        self.preferred = preferred
    }

    public var isEmpty: Bool { level == nil && frequency == nil && preferred.isEmpty }
}

public enum MealRegularity: String, Codable, CaseIterable, Sendable {
    case regular
    case mostDays
    case oftenSkip
}

public enum DietaryPattern: String, Codable, CaseIterable, Sendable {
    case noRestrictions
    case vegetarian
    case vegan
    case pescatarian
    case other
    case preferNotToSay
}

/// High-level eating situations that change which food-group suggestions are useful.
/// Intentionally excludes calories, weight and body-shape topics.
public enum EatingChallenge: String, Codable, CaseIterable, Sendable {
    case skipBreakfast
    case lowAppetite
    case pickyEating
    case fewCalciumFoods
    case busySchedule
    case foodAllergies
}

public enum HydrationHabit: String, Codable, CaseIterable, Sendable {
    case mostlyWater
    case mixed
    case mostlySweetDrinks
}

public struct NutritionBaseline: Codable, Hashable, Sendable {
    public var mealRegularity: MealRegularity?
    public var pattern: DietaryPattern?
    public var challenges: [EatingChallenge]
    public var hydration: HydrationHabit?

    public init(mealRegularity: MealRegularity? = nil, pattern: DietaryPattern? = nil, challenges: [EatingChallenge] = [], hydration: HydrationHabit? = nil) {
        self.mealRegularity = mealRegularity
        self.pattern = pattern
        self.challenges = challenges
        self.hydration = hydration
    }

    public var isEmpty: Bool { mealRegularity == nil && pattern == nil && challenges.isEmpty && hydration == nil }
}

public enum Goal: String, Codable, CaseIterable, Sendable {
    case understandGrowth
    case trackHeight
    case understandPercentile
    case seeChanges
    case healthierRoutines
    case sleepConsistency
    case nutritionHabits
    case longTermRecord
    case knowWhenToSeeDoctor

    /// Goals that only make sense while still growing.
    public var requiresGrowingAge: Bool {
        switch self {
        case .understandGrowth, .understandPercentile, .seeChanges: return true
        default: return false
        }
    }
}

/// What the person expects from the app. Used to set tone and to surface safety guidance;
/// `concerned` never triggers a diagnosis, only education and a suggestion to see a professional.
public enum UserIntent: String, Codable, CaseIterable, Sendable {
    case curious
    case tracking
    case healthyHabits
    case understanding
    case concerned
}
