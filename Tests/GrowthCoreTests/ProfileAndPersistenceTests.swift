import XCTest
@testable import GrowthCore

final class ProfileBuilderTests: XCTestCase {
    let builder = ProfileBuilder(flow: T.flow())

    func testHiddenAnswersAreNotStored() throws {
        // Someone answers growth questions, then corrects the birth date to an adult age.
        var draft = T.completeDraft(birth: T.date(1992, 4, 4))
        draft.mother = .known(heightCm: 168, source: .measured)
        draft.recentGrowthChange = .faster
        draft.hasHistory = true
        draft.history = [HistoryEntryDraft(date: T.date(2020, 1, 1), heightCm: 170)]
        draft.goals = [.understandPercentile, .sleepConsistency]
        let profile = try builder.build(from: draft)
        XCTAssertEqual(profile.parentHeights, ParentHeights())
        XCTAssertNil(profile.recentGrowthChange)
        XCTAssertEqual(profile.measurements.count, 1)
        XCTAssertEqual(profile.goals, [.sleepConsistency], "Growth-only goals dropped for adults")
    }

    func testHistoryKeptOnlyWhenAnsweredYes() throws {
        var draft = T.completeDraft()
        draft.history = [HistoryEntryDraft(date: T.date(2025, 1, 1), heightCm: 150)]
        draft.hasHistory = false
        XCTAssertEqual(try builder.build(from: draft).measurements.count, 1)
        draft.hasHistory = true
        XCTAssertEqual(try builder.build(from: draft).measurements.count, 2)
    }

    func testMultipleHistoryEntriesAreSortedAndBlankRowsIgnored() throws {
        var draft = T.completeDraft()
        draft.hasHistory = true
        draft.history = [
            HistoryEntryDraft(date: T.date(2025, 6, 1), heightCm: 155),
            HistoryEntryDraft(),
            HistoryEntryDraft(date: T.date(2024, 6, 1), heightCm: 150),
            HistoryEntryDraft(date: T.date(2023, 6, 1), heightCm: 144.5)
        ]
        let profile = try builder.build(from: draft)
        XCTAssertEqual(profile.measurements.map(\.heightCm), [144.5, 150, 155, 158.2])
        XCTAssertEqual(profile.measurements.filter { $0.origin == .onboardingHistory }.count, 3)
    }

    func testMissingParentHeightsProduceEmptyParentData() throws {
        let profile = try builder.build(from: T.completeDraft())
        XCTAssertNil(profile.parentHeights.mother)
        XCTAssertFalse(profile.parentHeights.bothKnown)
    }

    func testNicknameIgnoredForSelfAndTrimmedForChild() throws {
        var draft = T.completeDraft()
        draft.nickname = "Sneaky"
        XCTAssertNil(try builder.build(from: draft).nickname)
        var child = T.completeDraft(subject: .child, birth: T.date(2017, 1, 1))
        child.nickname = "  Sam  "
        XCTAssertEqual(try builder.build(from: child).nickname, "Sam")
        child.nickname = "   "
        XCTAssertNil(try builder.build(from: child).nickname)
    }

    func testErrors() {
        var draft = T.completeDraft()
        draft.currentHeightCm = 20
        XCTAssertThrowsError(try builder.build(from: draft)) { XCTAssertEqual($0 as? ProfileBuildError, .invalidCurrentHeight) }
        draft = T.completeDraft()
        draft.chartSex = nil
        XCTAssertThrowsError(try builder.build(from: draft)) { XCTAssertEqual($0 as? ProfileBuildError, .missingChartSex) }
        draft = T.completeDraft()
        draft.hasHistory = true
        draft.history = [HistoryEntryDraft(date: nil, heightCm: 140)]
        XCTAssertThrowsError(try builder.build(from: draft)) { XCTAssertEqual($0 as? ProfileBuildError, .invalidHistory) }
    }

    func testSleepDurationAcrossMidnight() {
        XCTAssertEqual(SleepBaseline(bedtime: TimeOfDay(hour: 22, minute: 30), wakeTime: TimeOfDay(hour: 7, minute: 0)).typicalDurationMinutes, 510)
        XCTAssertEqual(SleepBaseline(bedtime: TimeOfDay(hour: 0, minute: 30), wakeTime: TimeOfDay(hour: 8, minute: 0)).typicalDurationMinutes, 450)
        XCTAssertNil(SleepBaseline(bedtime: TimeOfDay(hour: 22, minute: 0)).typicalDurationMinutes)
    }
}

final class PersistenceTests: XCTestCase {
    func testFileStoreRoundTrip() throws {
        let store = try T.makeFileStore()
        XCTAssertTrue({ if case .empty = store.load() { return true }; return false }())
        let profile = try ProfileBuilder(flow: T.flow()).build(from: T.completeDraft())
        let snapshot = AppSnapshot(profiles: [profile], activeProfileID: profile.id, onboardingDraft: T.completeDraft())
        try store.save(snapshot)
        guard case .loaded(let loaded) = store.load() else { return XCTFail("Expected loaded") }
        XCTAssertEqual(loaded, snapshot)
    }

    func testOlderFileWithMissingFieldsStillLoads() throws {
        // Simulates a file written before later fields existed.
        let id = UUID()
        let json = """
        {"profiles":[{"id":"\(id.uuidString)","subject":"myself","birthDate":1300000000,"chartSex":"male"}]}
        """
        let store = try T.makeFileStore()
        try Data(json.utf8).write(to: store.fileURL)
        guard case .loaded(let loaded) = store.load() else { return XCTFail("Expected tolerant decoding") }
        let profile = try XCTUnwrap(loaded.profiles.first)
        XCTAssertEqual(profile.id, id)
        XCTAssertEqual(profile.unitPreference, .centimeters)
        XCTAssertTrue(profile.goals.isEmpty)
        XCTAssertEqual(loaded.schemaVersion, AppSnapshot.currentSchemaVersion)
    }

    func testUnknownStepInSavedDraftFallsBackSafely() throws {
        let json = """
        {"onboardingDraft":{"mode":"firstRun","currentStep":"weightQuestionFromTheFuture","subject":"child"}}
        """
        let store = try T.makeFileStore()
        try Data(json.utf8).write(to: store.fileURL)
        guard case .loaded(let loaded) = store.load() else { return XCTFail() }
        XCTAssertEqual(loaded.onboardingDraft?.currentStep, .welcome)
        XCTAssertEqual(loaded.onboardingDraft?.subject, .child)
    }

    func testCorruptFileIsReportedAndNeverDeletedAutomatically() throws {
        let store = try T.makeFileStore()
        try Data("{not json".utf8).write(to: store.fileURL)
        guard case .unreadable = store.load() else { return XCTFail("Expected unreadable") }
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
        try store.quarantineUnreadableData()
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
        let kept = try FileManager.default.contentsOfDirectory(atPath: store.fileURL.deletingLastPathComponent().path)
        XCTAssertTrue(kept.contains { $0.hasPrefix("profile-store.unreadable-") }, "Unreadable data is kept for recovery")
    }
}

final class RepositoryTests: XCTestCase {
    func testRepositoryRecoversFromUnreadableData() throws {
        try MainActor.assumeIsolated {
        let store = try T.makeFileStore()
        try Data("garbage".utf8).write(to: store.fileURL)
        let repository = AppRepository(store: store)
        guard case .unreadableData = repository.state else { return XCTFail() }
        try repository.startFreshAfterUnreadableData()
        XCTAssertEqual(repository.state, .ready)
        }
    }

    func testDeleteAllDataRemovesEverything() throws {
        try MainActor.assumeIsolated {
        let store = try T.makeFileStore()
        let repository = AppRepository(store: store)
        let profile = try ProfileBuilder(flow: T.flow()).build(from: T.completeDraft())
        repository.completeOnboarding(with: profile)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
        try repository.deleteAllData()
        XCTAssertTrue(repository.profiles.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
        }
    }

    func testSaveFailureIsSurfacedAndDataKeptInMemory() {
        MainActor.assumeIsolated {
        let (repository, store) = T.repository()
        store.failSaves = true
        repository.saveDraft(T.completeDraft())
        XCTAssertNotNil(repository.lastSaveError)
        XCTAssertNotNil(repository.snapshot.onboardingDraft)
        store.failSaves = false
        repository.saveDraft(T.completeDraft())
        XCTAssertNil(repository.lastSaveError)
        }
    }

    func testMeasurementsStaySortedAndLastOneCannotBeDeleted() throws {
        try MainActor.assumeIsolated {
        let (repository, _) = T.repository()
        let profile = try ProfileBuilder(flow: T.flow()).build(from: T.completeDraft())
        repository.completeOnboarding(with: profile)
        let only = profile.measurements[0]
        repository.deleteMeasurement(only.id, from: profile.id, at: T.today)
        XCTAssertEqual(repository.activeProfile?.measurements.count, 1)
        repository.addMeasurement(HeightMeasurement(date: T.date(2026, 1, 1), heightCm: 155, method: .home, origin: .manual), to: profile.id, at: T.today)
        XCTAssertEqual(repository.activeProfile?.measurements.map(\.heightCm), [155, 158.2])
        repository.deleteMeasurement(only.id, from: profile.id, at: T.today)
        XCTAssertEqual(repository.activeProfile?.measurements.map(\.heightCm), [155])
        }
    }
}
