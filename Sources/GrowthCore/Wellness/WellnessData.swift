import Foundation

/// Everything a profile logs beyond height: routines, posture checks, bedtime, meals and the puberty check.
///
/// Same evolution rule as `GrowthProfile`: every field decodes with `decodeIfPresent`, so files written before a
/// field existed always load. Nothing in here is an input to any growth number (percentile, speed, estimate).
public struct WellnessData: Codable, Hashable, Sendable {
    public var routineSessions: [RoutineSession]
    public var postureChecks: [PostureCheckRecord]
    public var bedtime: BedtimeSettings?
    public var meals: [MealDay]
    public var puberty: PubertyCheckRecord?
    /// Optional context people like to add (grandparents, siblings). Shown on the family card only;
    /// never used in the estimate because it adds little beyond the parents' heights.
    public var relatives: [RelativeHeight]

    public init(routineSessions: [RoutineSession] = [], postureChecks: [PostureCheckRecord] = [], bedtime: BedtimeSettings? = nil,
                meals: [MealDay] = [], puberty: PubertyCheckRecord? = nil, relatives: [RelativeHeight] = []) {
        self.routineSessions = routineSessions
        self.postureChecks = postureChecks
        self.bedtime = bedtime
        self.meals = meals
        self.puberty = puberty
        self.relatives = relatives
    }

    public static let empty = WellnessData()

    enum CodingKeys: String, CodingKey {
        case routineSessions, postureChecks, bedtime, meals, puberty, relatives
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        routineSessions = try c.decodeIfPresent([RoutineSession].self, forKey: .routineSessions) ?? []
        postureChecks = try c.decodeIfPresent([PostureCheckRecord].self, forKey: .postureChecks) ?? []
        bedtime = try c.decodeIfPresent(BedtimeSettings.self, forKey: .bedtime)
        meals = try c.decodeIfPresent([MealDay].self, forKey: .meals) ?? []
        puberty = try c.decodeIfPresent(PubertyCheckRecord.self, forKey: .puberty)
        relatives = try c.decodeIfPresent([RelativeHeight].self, forKey: .relatives) ?? []
    }

    public var latestPostureCheck: PostureCheckRecord? { postureChecks.max { $0.date < $1.date } }
}

/// One completed (or partly completed) guided routine.
public struct RoutineSession: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var routineID: String
    public var date: Date
    /// Seconds actually spent in moves (pauses excluded).
    public var activeSeconds: Int
    public var completed: Bool

    public init(id: UUID = UUID(), routineID: String, date: Date, activeSeconds: Int, completed: Bool) {
        self.id = id
        self.routineID = routineID
        self.date = date
        self.activeSeconds = activeSeconds
        self.completed = completed
    }
}

/// A saved posture check. Only the computed angles are stored: no image or video ever leaves the camera pipeline.
public struct PostureCheckRecord: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var date: Date
    public var view: PostureView
    public var score: Int
    public var shoulderTiltDegrees: Double?
    public var hipTiltDegrees: Double?
    public var headTiltDegrees: Double?
    public var forwardHeadDegrees: Double?

    public init(id: UUID = UUID(), date: Date, view: PostureView, score: Int, shoulderTiltDegrees: Double? = nil, hipTiltDegrees: Double? = nil,
                headTiltDegrees: Double? = nil, forwardHeadDegrees: Double? = nil) {
        self.id = id
        self.date = date
        self.view = view
        self.score = score
        self.shoulderTiltDegrees = shoulderTiltDegrees
        self.hipTiltDegrees = hipTiltDegrees
        self.headTiltDegrees = headTiltDegrees
        self.forwardHeadDegrees = forwardHeadDegrees
    }
}

public enum PostureView: String, Codable, Sendable, CaseIterable {
    /// Facing the camera: left/right balance of head, shoulders and hips.
    case front
    /// Side on: how far the head sits in front of the shoulders ("tech neck").
    case side
}

/// The bedtime planner's choices. Times are minutes after midnight so they survive time-zone changes.
public struct BedtimeSettings: Codable, Hashable, Sendable {
    public var wakeMinutes: Int
    /// Overrides the age-based sleep target when set (hours × 60).
    public var targetSleepMinutes: Int?
    public var windDownMinutes: Int
    public var remindersOn: Bool

    public init(wakeMinutes: Int = 7 * 60, targetSleepMinutes: Int? = nil, windDownMinutes: Int = 30, remindersOn: Bool = false) {
        self.wakeMinutes = wakeMinutes
        self.targetSleepMinutes = targetSleepMinutes
        self.windDownMinutes = windDownMinutes
        self.remindersOn = remindersOn
    }
}

/// Food groups eaten on a day. No calories, no portions, no weights: a simple variety check.
public struct MealDay: Codable, Hashable, Sendable {
    public var date: Date
    public var groups: [FoodGroup]

    public init(date: Date, groups: [FoodGroup]) {
        self.date = date
        self.groups = groups
    }
}

public enum FoodGroup: String, Codable, Sendable, CaseIterable, Identifiable {
    case protein, dairy, vegetables, fruit, wholeGrains, water

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .protein: return "Protein"
        case .dairy: return "Calcium foods"
        case .vegetables: return "Vegetables"
        case .fruit: return "Fruit"
        case .wholeGrains: return "Whole grains"
        case .water: return "Water through the day"
        }
    }

    public var examples: String {
        switch self {
        case .protein: return "Eggs, beans, lentils, fish, chicken, tofu, nuts"
        case .dairy: return "Milk, yoghurt, cheese, fortified plant milk"
        case .vegetables: return "Any kind, fresh or frozen"
        case .fruit: return "Fresh, frozen or dried"
        case .wholeGrains: return "Oats, brown rice, wholemeal bread"
        case .water: return "Water instead of sugary drinks"
        }
    }

    public var symbol: String {
        switch self {
        case .protein: return "fish"
        case .dairy: return "cup.and.saucer"
        case .vegetables: return "carrot"
        case .fruit: return "leaf"
        case .wholeGrains: return "takeoutbag.and.cup.and.straw"
        case .water: return "drop"
        }
    }
}

/// Answers to the short, non-intimate puberty check.
public struct PubertyCheckRecord: Codable, Hashable, Sendable {
    public var date: Date
    public var answers: [String: String]
    public var stage: PubertyStage

    public init(date: Date, answers: [String: String], stage: PubertyStage) {
        self.date = date
        self.answers = answers
        self.stage = stage
    }
}

public enum PubertyStage: String, Codable, Sendable {
    case notStarted, early, middle, late, unsure
}

public struct RelativeHeight: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var relation: String
    public var heightCm: Double

    public init(id: UUID = UUID(), relation: String, heightCm: Double) {
        self.id = id
        self.relation = relation
        self.heightCm = heightCm
    }
}
