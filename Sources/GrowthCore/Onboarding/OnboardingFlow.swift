import Foundation

/// Pure branching rules. No state, no UI. Every rule documents *why* a step is shown,
/// matching the question-purpose table in docs/phase-2-foundation.md.
public struct OnboardingFlow: Sendable {
    public var today: Date
    public var calendar: Calendar

    public init(today: Date, calendar: Calendar) {
        self.today = today
        self.calendar = calendar
    }

    /// Age band from the draft, if a valid birth date was given. `nil` means "not known yet",
    /// in which case age-dependent steps are tentatively shown.
    public func ageBand(for draft: OnboardingDraft) -> AgeBand? {
        guard let birthDate = draft.birthDate,
              let age = AgeCalculator.age(birthDate: birthDate, on: today, calendar: calendar) else { return nil }
        return age.band
    }

    public func isVisible(_ step: OnboardingStep, in draft: OnboardingDraft) -> Bool {
        let band = ageBand(for: draft)
        let stillGrowing = band.map(\.isStillGrowing) ?? true
        switch step {
        case .welcome, .privacy:
            return draft.mode == .firstRun
        case .subject:
            return draft.mode == .firstRun
        case .nickname:
            // Only children get a nickname; it personalises parent-facing copy.
            return draft.subject == .child
        case .parentHeights:
            // Family-height context only matters while growing (2–17). Adults: data minimisation.
            return stillGrowing
        case .historyQuestion:
            // Past measurements show a trend for anyone still growing or close to adult height (2–20).
            return band != .adult
        case .historyEntry:
            return isVisible(.historyQuestion, in: draft) && draft.hasHistory == true
        case .growthChange:
            // Interpretation context for a trend, 2–20.
            return band != .adult
        case .concernSupport:
            // Safety: anyone who says they're worried gets calm guidance before continuing.
            return draft.intent == .concerned
        default:
            return true
        }
    }

    public func visibleSteps(for draft: OnboardingDraft) -> [OnboardingStep] {
        OnboardingStep.allCases.filter { isVisible($0, in: draft) }
    }

    public func next(after step: OnboardingStep, in draft: OnboardingDraft) -> OnboardingStep? {
        let steps = visibleSteps(for: draft)
        guard let index = steps.firstIndex(of: step) else { return steps.first }
        let nextIndex = steps.index(after: index)
        return nextIndex < steps.endIndex ? steps[nextIndex] : nil
    }

    public func previous(before step: OnboardingStep, in draft: OnboardingDraft) -> OnboardingStep? {
        let steps = visibleSteps(for: draft).filter { !$0.isTransient }
        guard let index = steps.firstIndex(of: step), index > steps.startIndex else { return nil }
        return steps[steps.index(before: index)]
    }

    /// When editing from the summary, continue only into steps that the edit made newly relevant
    /// and that still need an answer; otherwise return to the summary.
    public func nextWhileEditing(after step: OnboardingStep, in draft: OnboardingDraft) -> OnboardingStep {
        let dependents: [OnboardingStep]
        switch step {
        case .subject: dependents = [.nickname]
        case .birthDate: dependents = [.parentHeights, .historyQuestion, .growthChange]
        case .historyQuestion: dependents = [.historyEntry]
        case .intent: dependents = [.concernSupport]
        default: dependents = []
        }
        let pending = dependents.first { isVisible($0, in: draft) && needsAnswer($0, in: draft) }
        return pending ?? .summary
    }

    func needsAnswer(_ step: OnboardingStep, in draft: OnboardingDraft) -> Bool {
        switch step {
        case .nickname: return draft.nickname == nil
        case .parentHeights: return draft.mother == nil && draft.father == nil
        case .historyQuestion: return draft.hasHistory == nil
        case .historyEntry: return draft.history.allSatisfy(\.isBlank)
        case .growthChange: return draft.recentGrowthChange == nil
        case .concernSupport: return true
        default: return false
        }
    }

    // MARK: Validation

    public func birthDateValidation(for draft: OnboardingDraft) -> BirthDateValidation {
        BirthDateValidation.validate(draft.birthDate, subject: draft.subject, today: today, calendar: calendar)
    }

    public func currentMeasurementDate(for draft: OnboardingDraft) -> Date {
        draft.currentHeightDate ?? today
    }

    public func historyIssues(for draft: OnboardingDraft) -> [UUID: [HistoryEntryIssue]] {
        var result: [UUID: [HistoryEntryIssue]] = [:]
        for entry in draft.history where !entry.isBlank {
            let issues = HistoryValidation.issues(
                for: entry, in: draft.history, birthDate: draft.birthDate,
                currentMeasurementDate: currentMeasurementDate(for: draft), calendar: calendar
            )
            if !issues.isEmpty { result[entry.id] = issues }
        }
        return result
    }

    public func canContinue(from step: OnboardingStep, in draft: OnboardingDraft) -> Bool {
        switch step {
        case .privacy:
            return draft.privacyAcknowledged
        case .subject:
            return draft.subject != nil
        case .birthDate:
            return birthDateValidation(for: draft).age != nil
        case .chartSex:
            return draft.chartSex != nil
        case .currentHeight:
            return HeightValidation.validate(draft.currentHeightCm) == .valid
        case .parentHeights:
            return [draft.mother, draft.father].allSatisfy { answer in
                guard case .known(let cm, _) = answer else { return true }
                return HeightValidation.validate(cm, range: HeightValidation.parentRange) == .valid
            }
        case .historyQuestion:
            return draft.hasHistory != nil
        case .historyEntry:
            // Blank rows are ignored; partially filled or invalid rows block.
            return historyIssues(for: draft).isEmpty
        default:
            return true
        }
    }

    // MARK: Progress

    public func progress(for draft: OnboardingDraft) -> OnboardingProgress {
        let step = draft.currentStep
        let chapters = OnboardingChapter.tracked
        guard let chapterIndex = chapters.firstIndex(of: step.chapter) else {
            return OnboardingProgress(chapter: step.chapter, chapterIndex: nil, fractionWithinChapter: 0, overall: 0)
        }
        let chapterSteps = visibleSteps(for: draft).filter { $0.chapter == step.chapter }
        let position = chapterSteps.firstIndex(of: step) ?? 0
        let within = chapterSteps.isEmpty ? 0 : Double(position) / Double(chapterSteps.count)
        let overall = (Double(chapterIndex) + within) / Double(chapters.count)
        return OnboardingProgress(chapter: step.chapter, chapterIndex: chapterIndex, fractionWithinChapter: within, overall: overall)
    }
}

public struct OnboardingProgress: Equatable, Sendable {
    public var chapter: OnboardingChapter
    /// Index in `OnboardingChapter.tracked`, or `nil` during the introduction.
    public var chapterIndex: Int?
    public var fractionWithinChapter: Double
    /// 0…1 across all tracked chapters.
    public var overall: Double
}
