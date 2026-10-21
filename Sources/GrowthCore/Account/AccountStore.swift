import Foundation
import Observation

/// Keeps the signed-in session somewhere safe (the Keychain on iOS, memory in tests).
public protocol SessionStorage: Sendable {
    func load() -> AuthSession?
    func save(_ session: AuthSession?)
}

public final class InMemorySessionStorage: SessionStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var session: AuthSession?
    public init(_ session: AuthSession? = nil) { self.session = session }
    public func load() -> AuthSession? { lock.lock(); defer { lock.unlock() }; return session }
    public func save(_ session: AuthSession?) { lock.lock(); self.session = session; lock.unlock() }
}

/// Optional account: sign in with Apple or email, back up profiles, restore them on another iPhone, delete it all.
/// The app is fully usable signed out; nothing here gates a feature.
@MainActor
@Observable
public final class AccountStore {
    public enum Phase: Equatable, Sendable {
        case idle
        case working(String)
        case failed(String)
        case notice(String)
    }

    public private(set) var session: AuthSession?
    public private(set) var phase: Phase = .idle
    public private(set) var lastBackup: Date?
    /// True right after signing in, until the person decides between the account's backup and this iPhone's data.
    /// Automatic backups wait, so a new iPhone never overwrites an existing backup by accident.
    public private(set) var awaitingFirstSync = false
    /// Back up automatically a few seconds after changes while signed in.
    public var autoBackup: Bool {
        didSet { defaults?.set(autoBackup, forKey: Self.autoBackupKey) }
    }

    @ObservationIgnored public let backend: AccountBackend?
    @ObservationIgnored private let storage: SessionStorage
    @ObservationIgnored private let defaults: UserDefaults?
    @ObservationIgnored private var pendingBackup: Task<Void, Never>?
    static let autoBackupKey = "account.autoBackup"
    static let lastBackupKey = "account.lastBackup"

    public init(backend: AccountBackend?, storage: SessionStorage, defaults: UserDefaults? = .standard) {
        self.backend = backend
        self.storage = storage
        self.defaults = defaults
        self.session = backend == nil ? nil : storage.load()
        self.autoBackup = defaults?.object(forKey: Self.autoBackupKey) as? Bool ?? true
        self.lastBackup = defaults?.object(forKey: Self.lastBackupKey) as? Date
    }

    /// False when the build has no backend configured; the account section is then hidden.
    public var isAvailable: Bool { backend != nil }
    public var isSignedIn: Bool { session != nil }
    public var isWorking: Bool { if case .working = phase { return true }; return false }

    public func clearMessage() { if !isWorking { phase = .idle } }

    // MARK: Sign in

    public func signIn(email: String, password: String) async -> Bool {
        await run("Signing in…") { backend in
            let session = try await backend.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
            self.adopt(session)
        }
    }

    /// Returns true when signed in. If the project asks for email confirmation, shows a notice instead.
    public func signUp(email: String, password: String) async -> Bool {
        var signedIn = false
        _ = await run("Creating your account…") { backend in
            if let session = try await backend.signUp(email: email.trimmingCharacters(in: .whitespaces), password: password) {
                self.adopt(session)
                signedIn = true
            }
        }
        if !signedIn, case .idle = phase { phase = .notice("Check your inbox and tap the confirmation link, then sign in here.") }
        return signedIn
    }

    public func signInWithApple(identityToken: String, rawNonce: String) async -> Bool {
        await run("Signing in with Apple…") { backend in
            self.adopt(try await backend.signInWithApple(identityToken: identityToken, rawNonce: rawNonce))
        }
    }

    public func sendPasswordReset(email: String) async {
        let ok = await run("Sending…") { backend in try await backend.sendPasswordReset(email: email.trimmingCharacters(in: .whitespaces)) }
        if ok { phase = .notice("If there's an account for that email, a reset link is on its way.") }
    }

    public func signOut() async {
        pendingBackup?.cancel()
        if let session, let backend { await backend.signOut(session) }
        adopt(nil)
    }

    // MARK: Backup

    public func backUpNow(_ snapshot: AppSnapshot) async {
        let ok = await run("Backing up…") { backend in
            try await backend.uploadBackup(snapshot, session: try await self.validSession(backend))
        }
        if ok {
            markBackedUp()
            awaitingFirstSync = false
        }
    }

    /// Call after the person picked "use the backup" (or cancelled) on the first-sync choice.
    public func finishFirstSync() { awaitingFirstSync = false }

    /// Debounced automatic backup, called whenever the snapshot changes.
    public func snapshotDidChange(_ snapshot: AppSnapshot) {
        guard autoBackup, isSignedIn, !awaitingFirstSync, !snapshot.profiles.isEmpty else { return }
        pendingBackup?.cancel()
        pendingBackup = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard let self, !Task.isCancelled, let backend = self.backend else { return }
            do {
                try await backend.uploadBackup(snapshot, session: try await self.validSession(backend))
                self.markBackedUp()
            } catch AccountError.sessionExpired {
                self.adopt(nil)
                self.phase = .failed(AccountError.sessionExpired.message)
            } catch {
                // Silent: automatic backups retry on the next change. "Back up now" shows errors.
            }
        }
    }

    /// The account's backup, if any, for the restore confirmation.
    public func fetchBackup() async -> AccountBackend.Backup? {
        var result: AccountBackend.Backup?
        let ok = await run("Looking for your backup…") { backend in
            result = try await backend.downloadBackup(session: try await self.validSession(backend))
        }
        if ok && result == nil { phase = .notice("There's no backup on this account yet.") }
        return result
    }

    // MARK: Delete

    public func deleteAccount(appleAuthorizationCode: String?) async -> Bool {
        pendingBackup?.cancel()
        let ok = await run("Deleting your account…") { backend in
            try await backend.deleteAccount(session: try await self.validSession(backend), appleAuthorizationCode: appleAuthorizationCode)
        }
        if ok {
            adopt(nil)
            defaults?.removeObject(forKey: Self.lastBackupKey)
            lastBackup = nil
            phase = .notice("Your account and its backup were deleted. Data on this iPhone is untouched.")
        }
        return ok
    }

    // MARK: Internals

    private func adopt(_ session: AuthSession?) {
        if self.session == nil && session != nil { awaitingFirstSync = true }
        if session == nil { awaitingFirstSync = false }
        self.session = session
        storage.save(session)
    }

    private func markBackedUp() {
        let now = Date()
        lastBackup = now
        defaults?.set(now, forKey: Self.lastBackupKey)
    }

    private func validSession(_ backend: AccountBackend) async throws -> AuthSession {
        guard let session else { throw AccountError.sessionExpired }
        guard session.needsRefresh(now: Date()) else { return session }
        let refreshed = try await backend.refresh(session)
        adopt(refreshed)
        return refreshed
    }

    @discardableResult
    private func run(_ label: String, _ work: (AccountBackend) async throws -> Void) async -> Bool {
        guard let backend else { return false }
        phase = .working(label)
        do {
            try await work(backend)
            phase = .idle
            return true
        } catch let error as AccountError {
            if error == .sessionExpired { adopt(nil) }
            phase = .failed(error.message)
        } catch {
            phase = .failed(AccountError.server("").message)
        }
        return false
    }
}
