import Foundation
import Observation

public enum NavigationDirection: Sendable {
    case forward
    case backward
}

/// Drives onboarding. Every answer is written through to the repository immediately,
/// so closing or killing the app never loses progress.
@MainActor
@Observable
public final class OnboardingController {
    public private(set) var draft: OnboardingDraft
    public private(set) var direction: NavigationDirection = .forward
    public private(set) var completedProfile: GrowthProfile?
    public private(set) var finishError: ProfileBuildError?
    /// True when this session continued a previously saved draft.
    public let isResumed: Bool

    @ObservationIgnored private let repository: AppRepository
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored public let calendar: Calendar

    public init(repository: AppRepository, mode: OnboardingMode = .firstRun, now: @escaping () -> Date = Date.init, calendar: Calendar = .current) {
        self.repository = repository
        self.now = now
        self.calendar = calendar
        if var saved = repository.snapshot.onboardingDraft, saved.mode == mode {
            saved.currentStep = Self.resumableStep(for: saved, flow: OnboardingFlow(today: now(), calendar: calendar))
            draft = saved
            isResumed = true
        } else {
            draft = OnboardingDraft(mode: mode, startedAt: now())
            isResumed = false
        }
        // No write here: initialisers must be side-effect free (SwiftUI may construct views repeatedly).
        // The draft is persisted on the first answer or navigation.
    }

    public var flow: OnboardingFlow { OnboardingFlow(today: now(), calendar: calendar) }
    public var currentStep: OnboardingStep { draft.currentStep }
    public var progress: OnboardingProgress { flow.progress(for: draft) }
    public var canContinue: Bool { flow.canContinue(from: draft.currentStep, in: draft) }
    public var canGoBack: Bool { draft.editingFromSummary || flow.previous(before: draft.currentStep, in: draft) != nil }
    public var ageBand: AgeBand? { flow.ageBand(for: draft) }
    public var birthDateValidation: BirthDateValidation { flow.birthDateValidation(for: draft) }
    public var historyIssues: [UUID: [HistoryEntryIssue]] { flow.historyIssues(for: draft) }
    public var copy: OnboardingCopy { OnboardingCopy(draft: draft, ageBand: ageBand) }
    public var today: Date { now() }

    // MARK: Answers

    public func update(_ mutate: (inout OnboardingDraft) -> Void) {
        var copy = draft
        mutate(&copy)
        if copy.currentHeightCm != nil && copy.currentHeightDate == nil {
            copy.currentHeightDate = calendar.startOfDay(for: now())
        }
        copy.updatedAt = now()
        draft = copy
        repository.saveDraft(draft)
    }

    // MARK: Navigation

    public func goNext() {
        guard canContinue else { return }
        let step = draft.currentStep
        if step == .privacy {
            repository.acknowledgePrivacy(at: now())
        }
        let destination: OnboardingStep?
        if draft.editingFromSummary {
            destination = flow.nextWhileEditing(after: step, in: draft)
        } else {
            destination = flow.next(after: step, in: draft)
        }
        guard let destination else { return }
        move(to: destination, direction: .forward)
        if destination == .summary { update { $0.editingFromSummary = false } }
    }

    /// "Skip" clears this step's answers so nothing half-entered is stored, then moves on.
    public func skip() {
        guard draft.currentStep.isSkippable else { return }
        update { draft in
            switch draft.currentStep {
            case .nickname: draft.nickname = nil
            case .parentHeights: draft.mother = nil; draft.father = nil
            case .growthChange: draft.recentGrowthChange = nil
            case .sleep: draft.sleep = SleepBaseline()
            case .activity: draft.activity = ActivityBaseline()
            case .nutrition: draft.nutrition = NutritionBaseline()
            case .goals: draft.goals = []
            case .intent: draft.intent = nil
            default: break
            }
        }
        let destination = draft.editingFromSummary
            ? flow.nextWhileEditing(after: draft.currentStep, in: draft)
            : flow.next(after: draft.currentStep, in: draft)
        if let destination { move(to: destination, direction: .forward) }
        if draft.currentStep == .summary { update { $0.editingFromSummary = false } }
    }

    public func goBack() {
        if draft.editingFromSummary {
            update { $0.editingFromSummary = false }
            move(to: .summary, direction: .backward)
            return
        }
        guard let destination = flow.previous(before: draft.currentStep, in: draft) else { return }
        move(to: destination, direction: .backward)
    }

    /// Jump from the summary to change an answer; Continue returns to the summary.
    public func edit(_ step: OnboardingStep) {
        guard flow.isVisible(step, in: draft) else { return }
        update { $0.editingFromSummary = true }
        move(to: step, direction: .backward)
    }

    /// A person under 13 tried to set up their own profile: hand over to a parent/guardian.
    /// The date of birth already entered belongs to the child, so it is kept.
    public func switchToGuardianSetup() {
        update { $0.subject = .child }
        move(to: .nickname, direction: .forward)
    }

    public func finish() {
        do {
            let profile = try ProfileBuilder(flow: flow).build(from: draft)
            repository.completeOnboarding(with: profile)
            completedProfile = profile
            finishError = nil
        } catch let error as ProfileBuildError {
            finishError = error
        } catch {
            finishError = nil
        }
    }

    private func move(to step: OnboardingStep, direction: NavigationDirection) {
        self.direction = direction
        update { $0.currentStep = step }
    }

    /// The saved step may have become hidden (e.g. after a code update) or be a transient screen.
    static func resumableStep(for draft: OnboardingDraft, flow: OnboardingFlow) -> OnboardingStep {
        let visible = flow.visibleSteps(for: draft)
        if visible.contains(draft.currentStep) && !draft.currentStep.isTransient { return draft.currentStep }
        let order = OnboardingStep.allCases
        let savedIndex = order.firstIndex(of: draft.currentStep) ?? 0
        return visible.first { order.firstIndex(of: $0)! > savedIndex && !$0.isTransient } ?? visible.first ?? .welcome
    }
}
