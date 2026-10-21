import XCTest
@testable import GrowthCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Replays canned responses and records requests, so the account client is tested without a server.
final class StubTransport: HTTPTransport, @unchecked Sendable {
    struct Reply { var status: Int; var body: String }
    private let lock = NSLock()
    private var replies: [Reply]
    private(set) var requests: [URLRequest] = []

    init(_ replies: [Reply]) { self.replies = replies }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let reply: Reply = lock.withLock {
            requests.append(request)
            return replies.isEmpty ? Reply(status: 500, body: "{}") : replies.removeFirst()
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: nil)!
        return (Data(reply.body.utf8), response)
    }

    func body(_ index: Int) -> [String: Any] {
        guard let data = requests[index].httpBody else { return [:] }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }
}

final class AccountTests: XCTestCase {
    let config = BackendConfig(baseURL: URL(string: "https://example.supabase.co")!, anonKey: "anon")
    let tokenReply = StubTransport.Reply(status: 200, body: """
    {"access_token":"at","refresh_token":"rt","expires_in":3600,"user":{"id":"u1","email":"a@b.co"}}
    """)

    func backend(_ transport: StubTransport) -> AccountBackend {
        AccountBackend(config: config, transport: transport, now: { T.today })
    }

    func testConfigNeedsHTTPSAndBothValues() {
        XCTAssertNil(BackendConfig.from(infoDictionary: nil))
        XCTAssertNil(BackendConfig.from(infoDictionary: ["StatureBackendURL": "$(STATURE_BACKEND_URL)", "StatureBackendAnonKey": "k"]))
        XCTAssertNil(BackendConfig.from(infoDictionary: ["StatureBackendURL": "http://x.co", "StatureBackendAnonKey": "k"]))
        XCTAssertNil(BackendConfig.from(infoDictionary: ["StatureBackendURL": "https://x.co", "StatureBackendAnonKey": ""]))
        XCTAssertEqual(BackendConfig.from(infoDictionary: ["StatureBackendURL": "https://x.co", "StatureBackendAnonKey": "k"])?.anonKey, "k")
    }

    @MainActor
    func testRestoreReplacesEverythingAndPicksAnActiveProfile() {
        let (repository, store) = T.repository()
        let profile = GrowthProfile(subject: .myself, birthDate: T.date(1990, 1, 1), chartSex: .male, unitPreference: .centimeters,
                                    measurements: [HeightMeasurement(date: T.today, heightCm: 178, method: .home, origin: .manual)],
                                    createdAt: T.today, updatedAt: T.today)
        repository.replaceAll(with: AppSnapshot(profiles: [profile], activeProfileID: UUID()))
        XCTAssertEqual(repository.activeProfile?.id, profile.id)
        if case .loaded(let saved) = store.load() { XCTAssertEqual(saved.profiles, [profile]) } else { XCTFail("restore is saved") }
    }

    func testEmailRule() {
        XCTAssertTrue(EmailRule.isValid("sam@example.com"))
        for bad in ["", "sam", "sam@", "@x.com", "sam@x", "sa m@x.com", "sam@.com"] { XCTAssertFalse(EmailRule.isValid(bad), bad) }
    }

    func testPasswordSignInBuildsSession() async throws {
        let transport = StubTransport([tokenReply])
        let session = try await backend(transport).signIn(email: "a@b.co", password: "secret123")
        XCTAssertEqual(session.userID, "u1")
        XCTAssertEqual(session.email, "a@b.co")
        XCTAssertEqual(session.provider, .email)
        XCTAssertEqual(session.expiresAt, T.today.addingTimeInterval(3600))
        let request = transport.requests[0]
        XCTAssertEqual(request.url?.path, "/auth/v1/token")
        XCTAssertEqual(request.url?.query, "grant_type=password")
        XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon")
        XCTAssertEqual(transport.body(0)["email"] as? String, "a@b.co")
    }

    func testAppleSignInSendsTokenAndNonce() async throws {
        let transport = StubTransport([tokenReply])
        let session = try await backend(transport).signInWithApple(identityToken: "idt", rawNonce: "n0nce")
        XCTAssertEqual(session.provider, .apple)
        XCTAssertEqual(transport.requests[0].url?.query, "grant_type=id_token")
        XCTAssertEqual(transport.body(0)["provider"] as? String, "apple")
        XCTAssertEqual(transport.body(0)["nonce"] as? String, "n0nce")
    }

    func testSignUpValidatesBeforeCallingAndHandlesConfirmation() async throws {
        let transport = StubTransport([StubTransport.Reply(status: 200, body: #"{"id":"u1","email":"a@b.co"}"#)])
        do { _ = try await backend(transport).signUp(email: "a@b.co", password: "short"); XCTFail() } catch { XCTAssertEqual(error as? AccountError, .weakPassword) }
        XCTAssertTrue(transport.requests.isEmpty)
        let session = try await backend(transport).signUp(email: "a@b.co", password: "long enough")
        XCTAssertNil(session, "confirmation required: no session yet")
    }

    func testServerErrorsMapToPlainMessages() {
        XCTAssertEqual(AccountBackend.error(status: 400, data: Data(#"{"error_code":"invalid_credentials","msg":"Invalid login credentials"}"#.utf8)), .invalidCredentials)
        XCTAssertEqual(AccountBackend.error(status: 400, data: Data(#"{"error_code":"email_not_confirmed"}"#.utf8)), .emailNotConfirmed)
        XCTAssertEqual(AccountBackend.error(status: 422, data: Data(#"{"error_code":"user_already_exists"}"#.utf8)), .emailInUse)
        XCTAssertEqual(AccountBackend.error(status: 401, data: Data()), .sessionExpired)
        for error in [AccountError.invalidCredentials, .emailNotConfirmed, .weakPassword, .emailInUse, .invalidEmail, .network, .sessionExpired, .server("")] {
            XCTAssertFalse(error.message.isEmpty)
        }
    }

    @MainActor
    func testBackupRoundTripsTheSnapshot() async throws {
        let (repository, _) = T.repository()
        let profile = GrowthProfile(subject: .child, nickname: "Maya", birthDate: T.date(2016, 4, 1), chartSex: .female, unitPreference: .centimeters,
                                    measurements: [HeightMeasurement(date: T.date(2026, 10, 1), heightCm: 132, method: .home, origin: .manual)],
                                    createdAt: T.today, updatedAt: T.today)
        repository.completeOnboarding(with: profile)
        let snapshot = repository.snapshot

        let upload = StubTransport([StubTransport.Reply(status: 201, body: "")])
        let session = AuthSession(accessToken: "at", refreshToken: "rt", expiresAt: T.today.addingTimeInterval(3600), userID: "u1", email: nil, provider: .email)
        try await backend(upload).uploadBackup(snapshot, session: session)
        XCTAssertEqual(upload.requests[0].url?.path, "/rest/v1/backups")
        XCTAssertEqual(upload.requests[0].value(forHTTPHeaderField: "Authorization"), "Bearer at")
        let row = upload.body(0)
        XCTAssertEqual(row["user_id"] as? String, "u1")

        let rows: [[String: Any]] = [["data": row["data"]!, "updated_at": "2026-10-18T09:00:00.000Z"]]
        let rowJSON = try JSONSerialization.data(withJSONObject: rows)
        let download = StubTransport([StubTransport.Reply(status: 200, body: String(decoding: rowJSON, as: UTF8.self))])
        let backup = try await backend(download).downloadBackup(session: session)
        XCTAssertEqual(backup?.snapshot.profiles, snapshot.profiles)
        XCTAssertNotNil(backup?.updatedAt)

        let empty = StubTransport([StubTransport.Reply(status: 200, body: "[]")])
        let none = try await backend(empty).downloadBackup(session: session)
        XCTAssertNil(none)
    }

    @MainActor
    func testStoreSignsInPersistsAndSignsOut() async {
        let storage = InMemorySessionStorage()
        let store = AccountStore(backend: backend(StubTransport([tokenReply, StubTransport.Reply(status: 204, body: "")])), storage: storage, defaults: nil)
        XCTAssertFalse(store.isSignedIn)
        let ok = await store.signIn(email: "a@b.co", password: "secret123")
        XCTAssertTrue(ok)
        XCTAssertTrue(store.isSignedIn)
        XCTAssertEqual(storage.load()?.userID, "u1")
        XCTAssertTrue(store.awaitingFirstSync, "no automatic backup until the person picks which data to keep")
        await store.signOut()
        XCTAssertFalse(store.isSignedIn)
        XCTAssertNil(storage.load())
    }

    @MainActor
    func testStoreShowsFailureMessage() async {
        let store = AccountStore(backend: backend(StubTransport([StubTransport.Reply(status: 400, body: #"{"error_code":"invalid_credentials"}"#)])),
                                 storage: InMemorySessionStorage(), defaults: nil)
        let ok = await store.signIn(email: "a@b.co", password: "wrong-pass")
        XCTAssertFalse(ok)
        XCTAssertEqual(store.phase, .failed(AccountError.invalidCredentials.message))
    }

    @MainActor
    func testWithoutBackendAccountsAreHidden() {
        let store = AccountStore(backend: nil, storage: InMemorySessionStorage(), defaults: nil)
        XCTAssertFalse(store.isAvailable)
        XCTAssertFalse(store.isSignedIn)
    }

    @MainActor
    func testExpiredSessionIsRefreshedBeforeBackup() async {
        let old = AuthSession(accessToken: "old", refreshToken: "rt", expiresAt: Date().addingTimeInterval(-10), userID: "u1", email: "a@b.co", provider: .apple)
        let transport = StubTransport([tokenReply, StubTransport.Reply(status: 201, body: "")])
        let store = AccountStore(backend: AccountBackend(config: config, transport: transport), storage: InMemorySessionStorage(old), defaults: nil)
        await store.backUpNow(AppSnapshot())
        XCTAssertEqual(transport.requests.first?.url?.query, "grant_type=refresh_token")
        XCTAssertEqual(transport.requests.last?.value(forHTTPHeaderField: "Authorization"), "Bearer at")
        XCTAssertEqual(store.session?.provider, .apple, "refresh keeps the provider")
        XCTAssertNotNil(store.lastBackup)
    }
}
