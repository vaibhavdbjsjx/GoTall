import Foundation

/// Progress is shown by chapter, never as "7 / 31".
public enum OnboardingChapter: String, Codable, CaseIterable, Sendable {
    case introduction
    case profile
    case growth
    case lifestyle
    case goals
    case personalization

    /// Chapters shown in the progress indicator. The introduction sits before the indicator appears.
    public static let tracked: [OnboardingChapter] = [.profile, .growth, .lifestyle, .goals, .personalization]
}

public enum OnboardingStep: String, Codable, CaseIterable, Sendable {
    case welcome
    case privacy
    case subject
    case nickname
    case birthDate
    case chartSex
    case currentHeight
    case parentHeights
    case historyQuestion
    case historyEntry
    case growthChange
    case sleep
    case activity
    case nutrition
    case goals
    case intent
    case concernSupport
    case buildingProfile
    case summary

    public var chapter: OnboardingChapter {
        switch self {
        case .welcome, .privacy: return .introduction
        case .subject, .nickname, .birthDate, .chartSex, .currentHeight: return .profile
        case .parentHeights, .historyQuestion, .historyEntry, .growthChange: return .growth
        case .sleep, .activity, .nutrition: return .lifestyle
        case .goals, .intent, .concernSupport: return .goals
        case .buildingProfile, .summary: return .personalization
        }
    }

    /// Required steps block Continue until answered. Everything else offers Skip.
    /// Required data = the minimum needed for a growth chart: who, date of birth, chart, height.
    public var isRequired: Bool {
        switch self {
        case .subject, .birthDate, .chartSex, .currentHeight, .privacy, .historyQuestion: return true
        default: return false
        }
    }

    /// Steps that show a Skip button.
    public var isSkippable: Bool {
        switch self {
        case .nickname, .parentHeights, .growthChange, .sleep, .activity, .nutrition, .goals, .intent: return true
        default: return false
        }
    }

    /// Transient screens are not resumed into; resuming lands on the next real step.
    public var isTransient: Bool { self == .buildingProfile }
}
