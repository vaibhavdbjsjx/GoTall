import Foundation

public struct Age: Equatable, Sendable {
    public var years: Int
    public var months: Int
    /// Exact age in months using the CDC convention (days / 30.4375). Used by growth references later.
    public var exactMonths: Double

    public var band: AgeBand { AgeBand(years: years) }
}

/// Product age policy (docs/scientific-prediction-review.md §9).
public enum AgeBand: String, Codable, Sendable, CaseIterable {
    /// Under 2: outside the 2–20 y growth-reference range we support.
    case infant
    /// 2–12: parent-managed profiles only.
    case child
    /// 13–17
    case teen
    /// 18–20: near adult height, trend messaging only.
    case youngAdult
    /// 21+: no prediction.
    case adult

    public init(years: Int) {
        switch years {
        case ..<2: self = .infant
        case 2...12: self = .child
        case 13...17: self = .teen
        case 18...20: self = .youngAdult
        default: self = .adult
        }
    }

    /// Ages for which growth-specific questions (parent heights, history, growth change) are meaningful.
    public var isStillGrowing: Bool { self == .child || self == .teen }
}

public enum AgeCalculator {
    public static func age(birthDate: Date, on date: Date, calendar: Calendar) -> Age? {
        guard birthDate <= date else { return nil }
        let components = calendar.dateComponents([.year, .month], from: birthDate, to: date)
        guard let years = components.year, let months = components.month else { return nil }
        let days = date.timeIntervalSince(birthDate) / 86_400
        return Age(years: years, months: months, exactMonths: days / 30.4375)
    }
}

public enum BirthDateValidation: Equatable, Sendable {
    case valid(Age)
    case missing
    case inFuture
    /// Older than the supported maximum age; almost certainly a typo.
    case implausiblyOld
    /// Under 2 years old: outside the supported reference range.
    case tooYoung
    /// A person under 13 setting the app up for themselves: needs a parent or guardian.
    case needsGuardian(Age)

    public static let maximumYears = 100

    public static func validate(_ birthDate: Date?, subject: ProfileSubject?, today: Date, calendar: Calendar) -> BirthDateValidation {
        guard let birthDate else { return .missing }
        guard let age = AgeCalculator.age(birthDate: birthDate, on: today, calendar: calendar) else { return .inFuture }
        if age.years > maximumYears { return .implausiblyOld }
        if age.band == .infant { return .tooYoung }
        if subject == .myself && age.years < 13 { return .needsGuardian(age) }
        return .valid(age)
    }

    public var age: Age? {
        if case .valid(let age) = self { return age }
        return nil
    }
}
