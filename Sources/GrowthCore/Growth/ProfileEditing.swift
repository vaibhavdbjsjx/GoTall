import Foundation
import GrowthEngine

/// Validation for adding or editing a measurement after onboarding.
public struct MeasurementCheck: Sendable, Equatable {
    public enum Issue: Sendable, Equatable {
        case heightOutOfRange(HeightValidation.Result)
        case dateInFuture
        case dateBeforeBirth
    }
    /// Non-blocking: the person confirms and saves.
    public enum Warning: Sendable, Equatable {
        /// Another measurement exists on the same day; they'll be averaged.
        case sameDay(count: Int)
        /// More than 4 SD from the median for age: probably a typo or unit mix-up.
        case unusualForAge
        /// More than 1 cm lower than the previous measurement.
        case lowerThanPrevious(cm: Double)
        /// More than 1 cm taller than a later measurement.
        case tallerThanLater(cm: Double)
    }
    public var issues: [Issue]
    public var warnings: [Warning]
    public var canSave: Bool { issues.isEmpty }
}

public enum MeasurementValidator {
    public static let unusualZ = 4.0
    public static let orderToleranceCm = 1.0

    public static func check(heightCm: Double?, date: Date, editingID: UUID?, profile: GrowthProfile, today: Date,
                             calendar: Calendar, reference: GrowthReference = ReferenceRegistry.cdc2000) -> MeasurementCheck {
        var issues: [MeasurementCheck.Issue] = []
        var warnings: [MeasurementCheck.Warning] = []
        let heightResult = HeightValidation.validate(heightCm)
        if heightResult != .valid { issues.append(.heightOutOfRange(heightResult)) }
        let day = calendar.startOfDay(for: date)
        if day > calendar.startOfDay(for: today) { issues.append(.dateInFuture) }
        if day < calendar.startOfDay(for: profile.birthDate) { issues.append(.dateBeforeBirth) }

        let others = profile.measurements.filter { $0.id != editingID }
        let sameDay = others.filter { calendar.isDate($0.date, inSameDayAs: date) }.count
        if sameDay > 0 { warnings.append(.sameDay(count: sameDay)) }

        if let heightCm, heightResult == .valid {
            let age = AgeMath.exactAgeMonths(birthDate: profile.birthDate, on: date, calendar: calendar)
            if let p = try? PercentileCalculator.percentile(heightCm: heightCm, ageMonths: age, sex: profile.chartSex.referenceSex, reference: reference).get(),
               abs(p.z) > unusualZ {
                warnings.append(.unusualForAge)
            }
            let sorted = others.sorted { $0.date < $1.date }
            if let previous = sorted.last(where: { calendar.startOfDay(for: $0.date) < day }), heightCm < previous.heightCm - orderToleranceCm {
                warnings.append(.lowerThanPrevious(cm: previous.heightCm - heightCm))
            }
            if let later = sorted.first(where: { calendar.startOfDay(for: $0.date) > day }), heightCm > later.heightCm + orderToleranceCm {
                warnings.append(.tallerThanLater(cm: heightCm - later.heightCm))
            }
        }
        return MeasurementCheck(issues: issues, warnings: warnings)
    }

    public static func message(_ issue: MeasurementCheck.Issue) -> String {
        switch issue {
        case .heightOutOfRange(.tooShort): return "That looks too short. Check the number and the unit."
        case .heightOutOfRange(.tooTall): return "That looks too tall. Check the number and the unit."
        case .heightOutOfRange: return "Enter a height."
        case .dateInFuture: return "The date can't be in the future."
        case .dateBeforeBirth: return "The date is before the birth date."
        }
    }

    public static func message(_ warning: MeasurementCheck.Warning, unit: HeightUnit) -> String {
        switch warning {
        case .sameDay(let count):
            return count == 1 ? "There's already a measurement on this day. Both will be averaged." : "There are already \(count) measurements on this day. All will be averaged."
        case .unusualForAge: return "This height is very unusual for this age. Please double-check the number and the unit."
        case .lowerThanPrevious(let cm): return "This is \(HeightFormatter.changeString(centimeters: cm, unit: unit).dropFirst()) lower than the previous measurement. Worth a quick double-check."
        case .tallerThanLater(let cm): return "This is \(HeightFormatter.changeString(centimeters: cm, unit: unit).dropFirst()) taller than a later measurement. Worth a quick double-check."
        }
    }
}

/// Fields that are removed when an edit makes them irrelevant (same data-minimisation rule as onboarding).
public enum DroppedField: String, Sendable, Equatable, CaseIterable {
    case parentHeights
    case recentGrowthChange
    case growthOnlyGoals

    public var title: String {
        switch self {
        case .parentHeights: return "Parents' heights"
        case .recentGrowthChange: return "Recent growth change"
        case .growthOnlyGoals: return "Growth-only goals"
        }
    }
}

public enum BirthDateEditResult: Sendable, Equatable {
    case valid(dropping: [DroppedField])
    case invalid(BirthDateValidation)
    /// Some measurements would be dated before the new birth date.
    case conflictsWithMeasurements(count: Int)
}

public enum ProfileEditor {
    public static func checkBirthDate(_ newDate: Date, for profile: GrowthProfile, today: Date, calendar: Calendar) -> BirthDateEditResult {
        let validation = BirthDateValidation.validate(newDate, subject: profile.subject, today: today, calendar: calendar)
        guard validation.age != nil else { return .invalid(validation) }
        let conflicts = profile.measurements.filter { calendar.startOfDay(for: $0.date) < calendar.startOfDay(for: newDate) }.count
        if conflicts > 0 { return .conflictsWithMeasurements(count: conflicts) }
        var updated = profile
        updated.birthDate = newDate
        return .valid(dropping: droppedFields(for: updated, today: today, calendar: calendar))
    }

    /// Fields present on the profile that are hidden for its current age band.
    public static func droppedFields(for profile: GrowthProfile, today: Date, calendar: Calendar) -> [DroppedField] {
        guard let band = profile.age(on: today, calendar: calendar)?.band else { return [] }
        var fields: [DroppedField] = []
        if !band.isStillGrowing, profile.parentHeights != ParentHeights() { fields.append(.parentHeights) }
        if band == .adult, profile.recentGrowthChange != nil { fields.append(.recentGrowthChange) }
        if band == .adult, profile.goals.contains(where: \.requiresGrowingAge) { fields.append(.growthOnlyGoals) }
        return fields
    }

    /// Applies a birth-date change and removes fields that no longer apply. Callers must check first.
    public static func applyingBirthDate(_ newDate: Date, to profile: GrowthProfile, today: Date, calendar: Calendar) -> GrowthProfile {
        var updated = profile
        updated.birthDate = calendar.startOfDay(for: newDate)
        return pruned(updated, today: today, calendar: calendar)
    }

    /// Removes answers hidden for the profile's age band. Only called on explicit edits: natural ageing
    /// (a teen turning 18) does not delete data that was relevant when it was entered.
    public static func pruned(_ profile: GrowthProfile, today: Date, calendar: Calendar) -> GrowthProfile {
        var updated = profile
        for field in droppedFields(for: profile, today: today, calendar: calendar) {
            switch field {
            case .parentHeights: updated.parentHeights = ParentHeights()
            case .recentGrowthChange: updated.recentGrowthChange = nil
            case .growthOnlyGoals: updated.goals.removeAll(where: \.requiresGrowingAge)
            }
        }
        updated.updatedAt = today
        return updated
    }

    /// Parent-height edits are only allowed while growing and must be plausible.
    public static func canEditParentHeights(_ profile: GrowthProfile, today: Date, calendar: Calendar) -> Bool {
        profile.age(on: today, calendar: calendar)?.band.isStillGrowing == true
    }

    public static func isValidParentAnswer(_ answer: ParentHeightAnswer?) -> Bool {
        guard case .known(let cm, _)? = answer else { return true }
        return HeightValidation.validate(cm, range: HeightValidation.parentRange) == .valid
    }
}
