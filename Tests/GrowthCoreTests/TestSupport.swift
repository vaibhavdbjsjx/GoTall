import Foundation
@testable import GrowthCore

enum T {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    static let locale = Locale(identifier: "en_US_POSIX")

    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    /// Fixed "today" used across tests.
    static let today = date(2026, 10, 7)

    static func flow(today: Date = today) -> OnboardingFlow {
        OnboardingFlow(today: today, calendar: calendar)
    }

    static func draft(subject: ProfileSubject? = .myself, birth: Date? = date(2011, 3, 15), mode: OnboardingMode = .firstRun) -> OnboardingDraft {
        var draft = OnboardingDraft(mode: mode, startedAt: today)
        draft.privacyAcknowledged = true
        if mode == .firstRun { draft.subject = subject }
        draft.birthDate = birth
        return draft
    }

    /// A draft that satisfies every required step.
    static func completeDraft(subject: ProfileSubject = .myself, birth: Date = date(2011, 3, 15)) -> OnboardingDraft {
        var draft = self.draft(subject: subject, birth: birth)
        draft.chartSex = .female
        draft.currentHeightCm = 158.2
        draft.currentHeightDate = calendar.startOfDay(for: today)
        draft.hasHistory = false
        return draft
    }

    @MainActor
    static func repository(_ snapshot: AppSnapshot? = nil) -> (AppRepository, InMemoryProfileStore) {
        let store = InMemoryProfileStore(snapshot: snapshot)
        return (AppRepository(store: store), store)
    }

    static func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("growth-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("profile-store.json")
    }

    static func makeFileStore() throws -> FileProfileStore {
        let url = temporaryFileURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return FileProfileStore(fileURL: url)
    }
}
