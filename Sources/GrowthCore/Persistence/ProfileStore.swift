import Foundation

public enum StoreLoadResult: Sendable {
    case empty
    case loaded(AppSnapshot)
    /// The file exists but couldn't be decoded. It is never deleted automatically.
    case unreadable(String)
}

/// Storage boundary. The MVP uses a local JSON file; an iCloud (CloudKit) or SwiftData-backed
/// implementation can replace it later without touching onboarding or UI code.
public protocol ProfileStore: Sendable {
    func load() -> StoreLoadResult
    func save(_ snapshot: AppSnapshot) throws
    /// Moves an unreadable file aside (kept for recovery) so the app can start fresh.
    func quarantineUnreadableData() throws
    /// Permanently removes all stored data.
    func deleteAll() throws
}

/// Atomic JSON file in Application Support, protected with iOS Data Protection.
public final class FileProfileStore: ProfileStore, @unchecked Sendable {
    public let fileURL: URL
    private let lock = NSLock()

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Default location: Application Support/<bundle>/profile-store.json
    public static func defaultStore() throws -> FileProfileStore {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = base.appendingPathComponent("GrowthData", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return FileProfileStore(fileURL: directory.appendingPathComponent("profile-store.json"))
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        // Seconds since 1970 round-trips exactly, unlike ISO-8601 without fractional seconds.
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    public func load() -> StoreLoadResult {
        lock.lock(); defer { lock.unlock() }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .empty }
        do {
            let data = try Data(contentsOf: fileURL)
            let snapshot = try Self.makeDecoder().decode(AppSnapshot.self, from: data)
            return .loaded(SnapshotMigrator.migrate(snapshot))
        } catch {
            return .unreadable(String(describing: error))
        }
    }

    public func save(_ snapshot: AppSnapshot) throws {
        lock.lock(); defer { lock.unlock() }
        let data = try Self.makeEncoder().encode(snapshot)
        #if os(iOS)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: fileURL, options: [.atomic])
        #endif
    }

    public func quarantineUnreadableData() throws {
        lock.lock(); defer { lock.unlock() }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let stamp = Int(Date().timeIntervalSince1970)
        let destination = fileURL.deletingLastPathComponent().appendingPathComponent("profile-store.unreadable-\(stamp).json")
        try FileManager.default.moveItem(at: fileURL, to: destination)
    }

    public func deleteAll() throws {
        lock.lock(); defer { lock.unlock() }
        let directory = fileURL.deletingLastPathComponent()
        let items = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for item in items where item.lastPathComponent.hasPrefix("profile-store") {
            try FileManager.default.removeItem(at: item)
        }
    }
}

/// For previews and tests.
public final class InMemoryProfileStore: ProfileStore, @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot: AppSnapshot?
    public private(set) var saveCount = 0
    public var failSaves = false

    public init(snapshot: AppSnapshot? = nil) {
        self.snapshot = snapshot
    }

    public func load() -> StoreLoadResult {
        lock.lock(); defer { lock.unlock() }
        return snapshot.map(StoreLoadResult.loaded) ?? .empty
    }

    public func save(_ snapshot: AppSnapshot) throws {
        lock.lock(); defer { lock.unlock() }
        if failSaves { throw CocoaError(.fileWriteUnknown) }
        self.snapshot = snapshot
        saveCount += 1
    }

    public func quarantineUnreadableData() throws {}

    public func deleteAll() throws {
        lock.lock(); defer { lock.unlock() }
        snapshot = nil
    }
}

/// Upgrades older snapshots. Version 1 is the first schema, so this is currently a pass-through;
/// it exists so the upgrade path is designed in before the first release.
public enum SnapshotMigrator {
    public static func migrate(_ snapshot: AppSnapshot) -> AppSnapshot {
        var result = snapshot
        // Future: if result.schemaVersion < 2 { …transform… }
        result.schemaVersion = AppSnapshot.currentSchemaVersion
        return result
    }
}
