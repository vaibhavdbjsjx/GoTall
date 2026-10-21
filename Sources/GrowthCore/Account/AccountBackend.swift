import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Where accounts live. Accounts are optional: everything works without one, and signing in adds an encrypted-in-
/// transit backup of your profiles that you can restore on another iPhone. The backend is a Supabase project
/// (Auth + one Postgres table with row-level security + one Edge Function for account deletion). See
/// docs/backend-setup.md.
public struct BackendConfig: Sendable, Equatable {
    public var baseURL: URL
    public var anonKey: String

    public init(baseURL: URL, anonKey: String) {
        self.baseURL = baseURL
        self.anonKey = anonKey
    }

    /// Reads `StatureBackendURL` and `StatureBackendAnonKey` from Info.plist (set from build settings).
    /// Returns nil until both are filled in, which hides the account section instead of showing a broken one.
    public static func from(infoDictionary: [String: Any]?) -> BackendConfig? {
        guard let raw = infoDictionary?["StatureBackendURL"] as? String, !raw.isEmpty, !raw.contains("$("),
              let url = URL(string: raw), url.scheme == "https",
              let key = infoDictionary?["StatureBackendAnonKey"] as? String, !key.isEmpty, !key.contains("$(") else { return nil }
        return BackendConfig(baseURL: url, anonKey: key)
    }
}

/// A signed-in session. Tokens are kept in the Keychain by the app, never in the profile file.
public struct AuthSession: Codable, Sendable, Equatable {
    public enum Provider: String, Codable, Sendable { case email, apple }

    public var accessToken: String
    public var refreshToken: String
    public var expiresAt: Date
    public var userID: String
    public var email: String?
    public var provider: Provider

    public init(accessToken: String, refreshToken: String, expiresAt: Date, userID: String, email: String?, provider: Provider) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.userID = userID
        self.email = email
        self.provider = provider
    }

    public func needsRefresh(now: Date) -> Bool { expiresAt.timeIntervalSince(now) < 60 }
}

public enum AccountError: Error, Equatable, Sendable {
    case invalidCredentials
    case emailNotConfirmed
    case weakPassword
    case emailInUse
    case invalidEmail
    case network
    case sessionExpired
    case server(String)

    /// Plain-language message for the account screen.
    public var message: String {
        switch self {
        case .invalidCredentials: return "That email and password don't match. Check them and try again."
        case .emailNotConfirmed: return "Check your inbox and tap the confirmation link, then sign in."
        case .weakPassword: return "Use at least 8 characters for your password."
        case .emailInUse: return "There's already an account with this email. Try signing in instead."
        case .invalidEmail: return "That doesn't look like an email address."
        case .network: return "Couldn't reach the server. Check your connection and try again."
        case .sessionExpired: return "You've been signed out. Please sign in again."
        case .server(let detail): return detail.isEmpty ? "Something went wrong. Please try again." : detail
        }
    }
}

/// The network boundary, so the client can be tested without a server.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    public init() {}

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error { continuation.resume(throwing: error); return }
                guard let http = response as? HTTPURLResponse else { continuation.resume(throwing: AccountError.network); return }
                continuation.resume(returning: (data ?? Data(), http))
            }.resume()
        }
    }
}

/// Supabase Auth (GoTrue) and PostgREST over plain HTTPS. No third-party SDK.
public struct AccountBackend: Sendable {
    public let config: BackendConfig
    let transport: HTTPTransport
    let now: @Sendable () -> Date

    public init(config: BackendConfig, transport: HTTPTransport = URLSessionTransport(), now: @escaping @Sendable () -> Date = { Date() }) {
        self.config = config
        self.transport = transport
        self.now = now
    }

    // MARK: Auth

    /// Creates an email account. Returns nil when the project requires email confirmation first.
    public func signUp(email: String, password: String) async throws -> AuthSession? {
        guard EmailRule.isValid(email) else { throw AccountError.invalidEmail }
        guard password.count >= 8 else { throw AccountError.weakPassword }
        let data = try await call("auth/v1/signup", body: ["email": email, "password": password])
        let object = try Self.json(data)
        if object["access_token"] == nil { return nil }
        return try session(from: object, provider: .email)
    }

    public func signIn(email: String, password: String) async throws -> AuthSession {
        guard EmailRule.isValid(email) else { throw AccountError.invalidEmail }
        let data = try await call("auth/v1/token", query: [URLQueryItem(name: "grant_type", value: "password")],
                                  body: ["email": email, "password": password])
        return try session(from: try Self.json(data), provider: .email)
    }

    /// Sign in with Apple: the identity token and the raw nonce whose SHA-256 was sent to Apple.
    public func signInWithApple(identityToken: String, rawNonce: String) async throws -> AuthSession {
        let data = try await call("auth/v1/token", query: [URLQueryItem(name: "grant_type", value: "id_token")],
                                  body: ["provider": "apple", "id_token": identityToken, "nonce": rawNonce])
        return try session(from: try Self.json(data), provider: .apple)
    }

    public func refresh(_ session: AuthSession) async throws -> AuthSession {
        do {
            let data = try await call("auth/v1/token", query: [URLQueryItem(name: "grant_type", value: "refresh_token")],
                                      body: ["refresh_token": session.refreshToken])
            var refreshed = try self.session(from: try Self.json(data), provider: session.provider)
            if refreshed.email == nil { refreshed.email = session.email }
            return refreshed
        } catch AccountError.invalidCredentials {
            throw AccountError.sessionExpired
        }
    }

    public func sendPasswordReset(email: String) async throws {
        guard EmailRule.isValid(email) else { throw AccountError.invalidEmail }
        _ = try await call("auth/v1/recover", body: ["email": email])
    }

    public func signOut(_ session: AuthSession) async {
        _ = try? await call("auth/v1/logout", body: [:], token: session.accessToken)
    }

    // MARK: Backup

    /// Saves the whole snapshot as the account's single backup row (upsert on user_id).
    public func uploadBackup(_ snapshot: AppSnapshot, session: AuthSession) async throws {
        let payload = try FileProfileStore.makeEncoder().encode(snapshot)
        guard let snapshotObject = try JSONSerialization.jsonObject(with: payload) as? [String: Any] else { throw AccountError.server("") }
        let row: [String: Any] = ["user_id": session.userID, "data": snapshotObject, "schema_version": snapshot.schemaVersion,
                                  "updated_at": ISO8601DateFormatter().string(from: now())]
        _ = try await call("rest/v1/backups", query: [URLQueryItem(name: "on_conflict", value: "user_id")], body: row,
                           token: session.accessToken, headers: ["Prefer": "resolution=merge-duplicates,return=minimal"])
    }

    public struct Backup: Sendable, Equatable {
        public var snapshot: AppSnapshot
        public var updatedAt: Date?
    }

    /// The account's backup, or nil if it has none yet.
    public func downloadBackup(session: AuthSession) async throws -> Backup? {
        let data = try await call("rest/v1/backups", method: "GET",
                                  query: [URLQueryItem(name: "select", value: "data,updated_at"), URLQueryItem(name: "limit", value: "1")],
                                  token: session.accessToken)
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]], let row = rows.first,
              let object = row["data"] else { return nil }
        let raw = try JSONSerialization.data(withJSONObject: object)
        let snapshot = SnapshotMigrator.migrate(try FileProfileStore.makeDecoder().decode(AppSnapshot.self, from: raw))
        let updated = (row["updated_at"] as? String).flatMap(Self.parseDate)
        return Backup(snapshot: snapshot, updatedAt: updated)
    }

    /// Deletes the account and its backup on the server. For Apple accounts, pass a fresh authorization code so the
    /// server can also revoke the app's Sign in with Apple token, as Apple requires.
    public func deleteAccount(session: AuthSession, appleAuthorizationCode: String?) async throws {
        var body: [String: Any] = [:]
        if let appleAuthorizationCode { body["apple_authorization_code"] = appleAuthorizationCode }
        _ = try await call("functions/v1/delete-account", body: body, token: session.accessToken)
    }

    // MARK: Plumbing

    @discardableResult
    func call(_ path: String, method: String = "POST", query: [URLQueryItem] = [], body: [String: Any]? = nil,
              token: String? = nil, headers: [String: String] = [:]) async throws -> Data {
        var components = URLComponents(url: config.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw AccountError.server("") }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = method
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token ?? config.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        if let body, method != "GET" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch let error as AccountError {
            throw error
        } catch {
            throw AccountError.network
        }
        guard (200..<300).contains(response.statusCode) else { throw Self.error(status: response.statusCode, data: data) }
        return data
    }

    func session(from object: [String: Any], provider: AuthSession.Provider) throws -> AuthSession {
        guard let access = object["access_token"] as? String, let refresh = object["refresh_token"] as? String,
              let user = object["user"] as? [String: Any], let id = user["id"] as? String else { throw AccountError.server("") }
        let expiresIn = (object["expires_in"] as? Double) ?? (object["expires_in"] as? Int).map(Double.init) ?? 3600
        return AuthSession(accessToken: access, refreshToken: refresh, expiresAt: now().addingTimeInterval(expiresIn),
                           userID: id, email: user["email"] as? String, provider: provider)
    }

    static func json(_ data: Data) throws -> [String: Any] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw AccountError.server("") }
        return object
    }

    static func error(status: Int, data: Data) -> AccountError {
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let code = (object["error_code"] as? String) ?? (object["code"] as? String) ?? (object["error"] as? String) ?? ""
        let text = ((object["msg"] as? String) ?? (object["message"] as? String) ?? (object["error_description"] as? String) ?? "").lowercased()
        if code == "email_not_confirmed" || text.contains("not confirmed") { return .emailNotConfirmed }
        if code == "weak_password" || text.contains("password should") { return .weakPassword }
        if code == "user_already_exists" || code == "email_exists" || text.contains("already registered") { return .emailInUse }
        if code == "email_address_invalid" || text.contains("invalid format") { return .invalidEmail }
        if code == "invalid_credentials" || code == "invalid_grant" || text.contains("invalid login") { return .invalidCredentials }
        if status == 401 { return .sessionExpired }
        if status == 429 { return .server("Too many attempts. Wait a minute and try again.") }
        return .server("")
    }

    static func parseDate(_ text: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
}

public enum EmailRule {
    public static func isValid(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard trimmed.count <= 254, let at = trimmed.firstIndex(of: "@"), !trimmed.contains(" ") else { return false }
        let local = trimmed[..<at]
        let domain = trimmed[trimmed.index(after: at)...]
        return !local.isEmpty && domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".") && !domain.contains("@")
    }
}
