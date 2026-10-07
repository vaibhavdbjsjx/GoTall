import Foundation

public enum ProfileBuildError: Error, Equatable, Sendable {
    case missingSubject
    case invalidBirthDate(BirthDateValidation)
    case missingChartSex
    case invalidCurrentHeight
    case invalidHistory
}

/// Converts a finished draft into a profile.
///
/// Data-minimisation rule: answers to steps that are *not visible* for the final answers are dropped.
/// Example: someone enters parent heights, then corrects their birth date to age 25 — the parent
/// heights are not stored, because we never use them for adults.
public struct ProfileBuilder: Sendable {
    public var flow: OnboardingFlow

    public init(flow: OnboardingFlow) {
        self.flow = flow
    }

    public func build(from draft: OnboardingDraft, id: UUID = UUID()) throws -> GrowthProfile {
        guard let subject = draft.subject else { throw ProfileBuildError.missingSubject }
        let dobValidation = flow.birthDateValidation(for: draft)
        guard dobValidation.age != nil, let birthDate = draft.birthDate else {
            throw ProfileBuildError.invalidBirthDate(dobValidation)
        }
        guard let chartSex = draft.chartSex else { throw ProfileBuildError.missingChartSex }
        guard HeightValidation.validate(draft.currentHeightCm) == .valid, let currentHeight = draft.currentHeightCm else {
            throw ProfileBuildError.invalidCurrentHeight
        }

        let visible = Set(flow.visibleSteps(for: draft))
        let now = flow.today

        var measurements = [HeightMeasurement(
            date: flow.currentMeasurementDate(for: draft),
            heightCm: currentHeight,
            method: draft.currentHeightMethod,
            origin: .onboardingCurrent
        )]

        if visible.contains(.historyEntry) {
            guard flow.historyIssues(for: draft).isEmpty else { throw ProfileBuildError.invalidHistory }
            for entry in draft.history where !entry.isBlank {
                guard let date = entry.date, let height = entry.heightCm else { continue }
                // History is self-reported from records or memory; we don't know how it was measured.
                measurements.append(HeightMeasurement(date: date, heightCm: height, method: .estimate, origin: .onboardingHistory))
            }
        }

        let trimmedNickname = draft.nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        let goals = draft.goals.filter { goal in
            !goal.requiresGrowingAge || (flow.ageBand(for: draft).map { $0 != .adult } ?? true)
        }

        return GrowthProfile(
            id: id,
            subject: subject,
            nickname: visible.contains(.nickname) && trimmedNickname?.isEmpty == false ? trimmedNickname : nil,
            birthDate: birthDate,
            chartSex: chartSex,
            unitPreference: draft.unit,
            measurements: measurements,
            parentHeights: visible.contains(.parentHeights) ? ParentHeights(mother: draft.mother, father: draft.father) : ParentHeights(),
            recentGrowthChange: visible.contains(.growthChange) ? draft.recentGrowthChange : nil,
            sleep: draft.sleep,
            activity: draft.activity,
            nutrition: draft.nutrition,
            goals: goals,
            intent: draft.intent,
            createdAt: now,
            updatedAt: now
        )
    }
}
