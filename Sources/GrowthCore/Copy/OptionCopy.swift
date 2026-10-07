import Foundation

/// Display text for answer options. Kept beside the models so new cases can't ship without copy.
public protocol OptionDisplayable {
    var title: String { get }
    var detail: String? { get }
    var symbol: String { get }
}

extension ProfileSubject: OptionDisplayable {
    public var title: String { self == .myself ? "Myself" : "My child" }
    public var detail: String? { self == .myself ? "Track my own growth" : "I'm a parent or guardian" }
    public var symbol: String { self == .myself ? "person" : "figure.and.child.holdinghands" }
}

extension GrowthChartSex: OptionDisplayable {
    public var title: String { self == .female ? "Female chart" : "Male chart" }
    public var detail: String? { nil }
    public var symbol: String { "chart.line.uptrend.xyaxis" }
}

extension MeasurementMethod: OptionDisplayable {
    public var title: String {
        switch self {
        case .home: return "At home"
        case .professional: return "Doctor or school"
        case .estimate: return "Estimate"
        }
    }
    public var detail: String? { nil }
    public var symbol: String {
        switch self {
        case .home: return "house"
        case .professional: return "stethoscope"
        case .estimate: return "questionmark.circle"
        }
    }
}

extension ParentHeightSource: OptionDisplayable {
    public var title: String { self == .measured ? "Measured" : "Estimate" }
    public var detail: String? { nil }
    public var symbol: String { self == .measured ? "ruler" : "questionmark.circle" }
}

extension RecentGrowthChange: OptionDisplayable {
    public var title: String {
        switch self {
        case .faster: return "Growing faster than before"
        case .slower: return "Growing slower than before"
        case .aboutTheSame: return "About the same"
        case .notSure: return "Not sure"
        }
    }
    public var detail: String? { nil }
    public var symbol: String {
        switch self {
        case .faster: return "arrow.up.right"
        case .slower: return "arrow.down.right"
        case .aboutTheSame: return "arrow.right"
        case .notSure: return "questionmark"
        }
    }
}

extension SleepConsistency: OptionDisplayable {
    public var title: String {
        switch self {
        case .similarEveryDay: return "About the same"
        case .laterOnWeekends: return "Later on weekends"
        case .veryDifferent: return "Varies a lot"
        }
    }
    public var detail: String? { nil }
    public var symbol: String { "calendar" }
}

extension ActivityLevel: OptionDisplayable {
    public var title: String {
        switch self {
        case .mostlySitting: return "Mostly sitting"
        case .lightlyActive: return "Lightly active"
        case .active: return "Active"
        case .veryActive: return "Very active"
        }
    }
    public var detail: String? {
        switch self {
        case .mostlySitting: return "School or desk for most of the day"
        case .lightlyActive: return "Walking and light movement"
        case .active: return "Regular exercise or sport"
        case .veryActive: return "Training most days"
        }
    }
    public var symbol: String {
        switch self {
        case .mostlySitting: return "chair.lounge"
        case .lightlyActive: return "figure.walk"
        case .active: return "figure.run"
        case .veryActive: return "flame"
        }
    }
}

extension ExerciseFrequency: OptionDisplayable {
    public var title: String {
        switch self {
        case .rarely: return "Rarely"
        case .oneToTwo: return "1–2"
        case .threeToFour: return "3–4"
        case .fivePlus: return "5+"
        }
    }
    public var detail: String? { nil }
    public var symbol: String { "calendar" }
}

extension ActivityType: OptionDisplayable {
    public var title: String {
        switch self {
        case .teamSports: return "Team sports"
        case .running: return "Running"
        case .swimming: return "Swimming"
        case .cycling: return "Cycling"
        case .strengthTraining: return "Strength training"
        case .dance: return "Dance"
        case .martialArts: return "Martial arts"
        case .racketSports: return "Racket sports"
        case .walking: return "Walking"
        case .yogaMobility: return "Yoga or stretching"
        case .other: return "Something else"
        }
    }
    public var detail: String? { nil }
    public var symbol: String {
        switch self {
        case .teamSports: return "sportscourt"
        case .running: return "figure.run"
        case .swimming: return "figure.pool.swim"
        case .cycling: return "bicycle"
        case .strengthTraining: return "dumbbell"
        case .dance: return "figure.dance"
        case .martialArts: return "figure.martial.arts"
        case .racketSports: return "figure.tennis"
        case .walking: return "figure.walk"
        case .yogaMobility: return "figure.yoga"
        case .other: return "ellipsis"
        }
    }
}

extension MealRegularity: OptionDisplayable {
    public var title: String {
        switch self {
        case .regular: return "Regular meals"
        case .mostDays: return "Regular most days"
        case .oftenSkip: return "Meals often skipped"
        }
    }
    public var detail: String? { nil }
    public var symbol: String { "fork.knife" }
}

extension DietaryPattern: OptionDisplayable {
    public var title: String {
        switch self {
        case .noRestrictions: return "No restrictions"
        case .vegetarian: return "Vegetarian"
        case .vegan: return "Vegan"
        case .pescatarian: return "Pescatarian"
        case .other: return "Other"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
    public var detail: String? { nil }
    public var symbol: String { "leaf" }
}

extension EatingChallenge: OptionDisplayable {
    public var title: String {
        switch self {
        case .skipBreakfast: return "Often skip breakfast"
        case .lowAppetite: return "Small appetite"
        case .pickyEating: return "Picky eating"
        case .fewCalciumFoods: return "Rarely have dairy or other calcium-rich foods"
        case .busySchedule: return "Busy schedule, irregular meals"
        case .foodAllergies: return "Food allergies or intolerances"
        }
    }
    public var detail: String? { nil }
    public var symbol: String { "circle" }
}

extension HydrationHabit: OptionDisplayable {
    public var title: String {
        switch self {
        case .mostlyWater: return "Mostly water"
        case .mixed: return "A mix"
        case .mostlySweetDrinks: return "Mostly sweet drinks"
        }
    }
    public var detail: String? { nil }
    public var symbol: String { "drop" }
}

extension Goal: OptionDisplayable {
    public var title: String {
        switch self {
        case .understandGrowth: return "Understand growth"
        case .trackHeight: return "Track height"
        case .understandPercentile: return "Understand the percentile"
        case .seeChanges: return "See how growth is changing"
        case .healthierRoutines: return "Build healthier routines"
        case .sleepConsistency: return "More consistent sleep"
        case .nutritionHabits: return "Better eating habits"
        case .longTermRecord: return "Keep a long-term record"
        case .knowWhenToSeeDoctor: return "Know when to talk to a doctor"
        }
    }
    public var detail: String? { nil }
    public var symbol: String {
        switch self {
        case .understandGrowth: return "lightbulb"
        case .trackHeight: return "ruler"
        case .understandPercentile: return "chart.bar.xaxis"
        case .seeChanges: return "chart.xyaxis.line"
        case .healthierRoutines: return "checklist"
        case .sleepConsistency: return "moon"
        case .nutritionHabits: return "carrot"
        case .longTermRecord: return "books.vertical"
        case .knowWhenToSeeDoctor: return "stethoscope"
        }
    }
}

extension UserIntent: OptionDisplayable {
    public var title: String {
        switch self {
        case .curious: return "Curious about growth"
        case .tracking: return "Want a reliable record"
        case .healthyHabits: return "Building healthy habits"
        case .understanding: return "Want to understand growth better"
        case .concerned: return "Worried about growth"
        }
    }
    public var detail: String? { nil }
    public var symbol: String {
        switch self {
        case .curious: return "sparkle.magnifyingglass"
        case .tracking: return "list.bullet.rectangle"
        case .healthyHabits: return "heart"
        case .understanding: return "book"
        case .concerned: return "exclamationmark.bubble"
        }
    }
}
