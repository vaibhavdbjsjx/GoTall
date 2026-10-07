import Foundation

/// Input-sanity bounds. These are *data-entry* limits to catch typos and unit mix-ups,
/// not clinical thresholds. Age-specific plausibility checks against growth references
/// arrive with the reference layer (Phase 5).
public enum HeightValidation {
    /// Covers ages 2+ including very short and very tall people.
    public static let personRange: ClosedRange<Double> = 60...250
    /// Adult parent heights.
    public static let parentRange: ClosedRange<Double> = 120...230
    /// A history entry taller than the current height by more than this prompts a gentle double-check.
    public static let shrinkWarningToleranceCm: Double = 2.0

    public enum Result: Equatable, Sendable {
        case valid
        case missing
        case tooShort
        case tooTall
    }

    public static func validate(_ centimeters: Double?, range: ClosedRange<Double> = personRange) -> Result {
        guard let centimeters, centimeters.isFinite else { return .missing }
        if centimeters < range.lowerBound { return .tooShort }
        if centimeters > range.upperBound { return .tooTall }
        return .valid
    }
}

public struct HistoryEntryDraft: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var date: Date?
    public var heightCm: Double?

    public init(id: UUID = UUID(), date: Date? = nil, heightCm: Double? = nil) {
        self.id = id
        self.date = date
        self.heightCm = heightCm
    }

    public var isBlank: Bool { date == nil && heightCm == nil }
}

public enum HistoryEntryIssue: Equatable, Sendable {
    case missingDate
    case missingHeight
    case heightOutOfRange
    case dateBeforeBirth
    case dateInFuture
    case dateNotBeforeCurrentMeasurement
    case duplicateDate
}

/// Non-blocking warnings: the person can confirm and continue.
public enum HistoryEntryWarning: Equatable, Sendable {
    case tallerThanCurrent
}

public enum HistoryValidation {
    public static let maximumEntries = 10

    public static func issues(
        for entry: HistoryEntryDraft,
        in entries: [HistoryEntryDraft],
        birthDate: Date?,
        currentMeasurementDate: Date,
        calendar: Calendar
    ) -> [HistoryEntryIssue] {
        var issues: [HistoryEntryIssue] = []
        if let date = entry.date {
            if let birthDate, date < calendar.startOfDay(for: birthDate) { issues.append(.dateBeforeBirth) }
            // Compare calendar days, not instants: the current height is dated at start of day.
            if calendar.startOfDay(for: date) > calendar.startOfDay(for: currentMeasurementDate) {
                issues.append(.dateInFuture)
            } else if calendar.isDate(date, inSameDayAs: currentMeasurementDate) {
                issues.append(.dateNotBeforeCurrentMeasurement)
            }
            let sameDay = entries.filter { $0.id != entry.id && $0.date.map { calendar.isDate($0, inSameDayAs: date) } == true }
            if !sameDay.isEmpty { issues.append(.duplicateDate) }
        } else {
            issues.append(.missingDate)
        }
        switch HeightValidation.validate(entry.heightCm) {
        case .missing: issues.append(.missingHeight)
        case .tooShort, .tooTall: issues.append(.heightOutOfRange)
        case .valid: break
        }
        return issues
    }

    public static func warnings(for entry: HistoryEntryDraft, currentHeightCm: Double?) -> [HistoryEntryWarning] {
        guard let height = entry.heightCm, let current = currentHeightCm else { return [] }
        return height > current + HeightValidation.shrinkWarningToleranceCm ? [.tallerThanCurrent] : []
    }
}
