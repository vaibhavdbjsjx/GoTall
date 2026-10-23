#if os(iOS)
import SwiftUI
import AuthenticationServices
import CryptoKit
import Security
import GrowthCore
import DesignSystem

// MARK: - Keychain

/// Stores the session in the Keychain, available after first unlock and never synced to other devices.
public final class KeychainSessionStorage: SessionStorage, @unchecked Sendable {
    private let service = "app.stature.account"
    private let account = "session"

    public init() {}

    public func load() -> AuthSession? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    public func save(_ session: AuthSession?) {
        SecItemDelete(baseQuery as CFDictionary)
        guard let session, let data = try? JSONEncoder().encode(session) else { return }
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }
}

// MARK: - Sign in with Apple

/// A random nonce for each Apple request; Apple gets its SHA-256, the server checks the raw value.
enum AppleNonce {
    static func make(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in charset.randomElement(using: &generator)! })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// Apple's button, styled to match the appearance, returning the identity token and authorization code.
struct AppleSignInButton: View {
    let label: SignInWithAppleButton.Label
    let onCredential: (_ identityToken: String, _ rawNonce: String, _ authorizationCode: String?) -> Void
    let onError: (String) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var nonce = AppleNonce.make()

    var body: some View {
        SignInWithAppleButton(label) { request in
            nonce = AppleNonce.make()
            request.requestedScopes = [.email]
            request.nonce = AppleNonce.sha256(nonce)
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let tokenData = credential.identityToken, let token = String(data: tokenData, encoding: .utf8) else {
                    onError("Apple didn't return a sign-in token. Please try again.")
                    return
                }
                let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
                onCredential(token, nonce, code)
            case .failure(let error):
                if (error as? ASAuthorizationError)?.code == .canceled { return }
                onError("Sign in with Apple didn't finish. Please try again.")
            }
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .accessibilityIdentifier("account.apple")
    }
}

// MARK: - Account screen

/// Optional account. Signed out: Sign in with Apple, or email and password. Signed in: backup status, back up now,
/// restore from backup, sign out, delete account.
struct AccountView: View {
    let repository: AppRepository
    @Environment(AccountStore.self) private var account
    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var restoreCandidate: AccountBackend.Backup?
    /// The restore choice shown right after signing in also offers keeping this iPhone's data.
    @State private var isFirstSync = false
    @State private var confirmsSignOut = false
    @State private var confirmsDelete = false
    @State private var needsAppleReauth = false
    @FocusState private var focus: Field?

    enum Mode: String, CaseIterable, Identifiable { case signIn, create; var id: String { rawValue } }
    enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                if let session = account.session {
                    signedIn(session)
                } else {
                    signedOut
                }
                message
            }
            .padding(DS.Spacing.page)
            .animation(Motion.standard, value: account.isSignedIn)
        }
        .scrollDismissesKeyboard(.interactively)
        .dsPageBackground()
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { account.clearMessage() }
        .confirmationDialog("Restore from backup?", isPresented: Binding(get: { restoreCandidate != nil }, set: { if !$0 { restoreCandidate = nil } }),
                            titleVisibility: .visible) {
            Button("Use the backup on this iPhone", role: .destructive) {
                if let backup = restoreCandidate { repository.replaceAll(with: backup.snapshot) }
                restoreCandidate = nil
                account.finishFirstSync()
            }
            if isFirstSync && !repository.profiles.isEmpty {
                Button("Keep this iPhone's data instead") {
                    restoreCandidate = nil
                    Task { await account.backUpNow(repository.snapshot) }
                }
            }
            Button("Cancel", role: .cancel) { restoreCandidate = nil }
        } message: {
            if let backup = restoreCandidate {
                Text("The backup has \(backup.snapshot.profiles.count) profile\(backup.snapshot.profiles.count == 1 ? "" : "s")\(backup.updatedAt.map { ", saved \($0.formatted(date: .abbreviated, time: .shortened))" } ?? ""). It replaces everything currently on this iPhone.")
            }
        }
        .confirmationDialog("Sign out?", isPresented: $confirmsSignOut, titleVisibility: .visible) {
            Button("Sign out") { Task { await account.signOut() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Your data stays on this iPhone. Automatic backups stop until you sign in again.") }
        .confirmationDialog("Delete your account?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Delete account and backup", role: .destructive) {
                if account.session?.provider == .apple { needsAppleReauth = true } else { Task { _ = await account.deleteAccount(appleAuthorizationCode: nil) } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account and its backup from our server. Data on this iPhone stays until you delete it in Profile › Privacy & data. A Gromax Pro purchase belongs to your Apple Account and isn't affected.")
        }
        .sheet(isPresented: $needsAppleReauth) { appleReauthSheet }
    }

    // MARK: Signed out

    private var signedOut: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Back up your profiles").font(DS.Typography.display).foregroundStyle(DS.Colors.textPrimary)
                Text("An account is optional. Signing in keeps a backup of your profiles, measurements and plan so you can restore them on a new iPhone.")
                    .font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
            }
            AppleSignInButton(label: .continue) { token, nonce, _ in
                Task { if await account.signInWithApple(identityToken: token, rawNonce: nonce) { await firstSync() } }
            } onError: { _ in }
            .disabled(account.isWorking)

            HStack {
                Rectangle().fill(DS.Colors.separator).frame(height: 1)
                Text("or with email").font(DS.Typography.caption).foregroundStyle(DS.Colors.textTertiary).fixedSize()
                Rectangle().fill(DS.Colors.separator).frame(height: 1)
            }
            .accessibilityHidden(true)

            Picker("Account", selection: $mode) {
                Text("Sign in").tag(Mode.signIn)
                Text("Create account").tag(Mode.create)
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, _ in account.clearMessage() }

            VStack(spacing: DS.Spacing.sm) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focus = .password }
                    .fieldStyle()
                    .accessibilityIdentifier("account.email")
                SecureField(mode == .create ? "Password (8+ characters)" : "Password", text: $password)
                    .textContentType(mode == .create ? .newPassword : .password)
                    .focused($focus, equals: .password)
                    .submitLabel(.go)
                    .onSubmit(submit)
                    .fieldStyle()
                    .accessibilityIdentifier("account.password")
            }
            AppButton(mode == .create ? "Create account" : "Sign in", isLoading: account.isWorking, action: submit)
                .disabled(email.isEmpty || password.isEmpty || account.isWorking)
                .accessibilityIdentifier("account.submit")
            if mode == .signIn {
                Button("Forgot password?") { Task { await account.sendPasswordReset(email: email) } }
                    .font(DS.Typography.footnote.weight(.semibold))
                    .tint(DS.Colors.accent)
                    .disabled(email.isEmpty || account.isWorking)
            }
            PrivacyNotice(items: [(symbol: "lock.shield", title: "What's stored",
                                   detail: "Your email and a backup of your profiles, sent over an encrypted connection and readable only by your account. Never sold, never used for ads.")])
        }
    }

    private func submit() {
        focus = nil
        Task {
            let ok: Bool
            if mode == .create {
                ok = await account.signUp(email: email, password: password)
            } else {
                ok = await account.signIn(email: email, password: password)
            }
            if ok {
                password = ""
                await firstSync()
            }
        }
    }

    /// After signing in: if the account already has a backup, ask which data to keep; otherwise back up this iPhone.
    private func firstSync() async {
        if let backup = await account.fetchBackup() {
            isFirstSync = true
            restoreCandidate = backup
        } else if !repository.profiles.isEmpty {
            await account.backUpNow(repository.snapshot)
        } else {
            account.finishFirstSync()
        }
    }

    // MARK: Signed in

    private func signedIn(_ session: AuthSession) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: session.provider == .apple ? "apple.logo" : "envelope.fill")
                    .font(.title2)
                    .foregroundStyle(DS.Colors.accent)
                    .frame(width: 52, height: 52)
                    .background(DS.Colors.accentSoft, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Signed in").font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                    Text(session.email ?? (session.provider == .apple ? "Apple Account" : "Your account"))
                        .font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
            .accessibilityElement(children: .combine)

            AppCard {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Label(account.lastBackup.map { "Backed up \($0.formatted(.relative(presentation: .named)))" } ?? "Not backed up yet",
                          systemImage: account.lastBackup == nil ? "icloud.slash" : "checkmark.icloud")
                        .font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                    Toggle(isOn: Bindable(account).autoBackup) {
                        Text("Back up automatically after changes").font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                    }
                    .tint(DS.Colors.accent)
                }
            }
            AppButton("Back up now", systemImage: "arrow.up.circle", isLoading: account.isWorking) {
                Task { await account.backUpNow(repository.snapshot) }
            }
            .disabled(account.isWorking)
            AppButton("Restore from backup", systemImage: "arrow.down.circle", kind: .secondary) {
                isFirstSync = false
                Task { restoreCandidate = await account.fetchBackup() }
            }
            .disabled(account.isWorking)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Button("Sign out") { confirmsSignOut = true }
                    .font(DS.Typography.subheadline.weight(.semibold))
                    .tint(DS.Colors.accent)
                Button("Delete account", role: .destructive) { confirmsDelete = true }
                    .font(DS.Typography.subheadline.weight(.semibold))
                    .accessibilityIdentifier("account.delete")
            }
            .disabled(account.isWorking)
        }
    }

    /// Apple asks apps to revoke their Sign in with Apple token when an account is deleted. That needs a fresh
    /// authorization code, so the person confirms with Apple once more.
    private var appleReauthSheet: some View {
        VStack(spacing: DS.Spacing.lg) {
            Text("Confirm with Apple").font(DS.Typography.title).foregroundStyle(DS.Colors.textPrimary)
            Text("To finish deleting your account, confirm it's you. This also removes \(BrandConfig.current.displayName) from the apps using your Apple Account.")
                .font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary).multilineTextAlignment(.center)
            AppleSignInButton(label: .continue) { _, _, code in
                needsAppleReauth = false
                Task { _ = await account.deleteAccount(appleAuthorizationCode: code) }
            } onError: { _ in needsAppleReauth = false }
            Button("Cancel") { needsAppleReauth = false }.tint(DS.Colors.accent)
        }
        .padding(DS.Spacing.page)
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private var message: some View {
        switch account.phase {
        case .failed(let text):
            InfoBanner(text, tone: .caution).accessibilityIdentifier("account.error")
        case .notice(let text):
            InfoBanner(text, tone: .info).accessibilityIdentifier("account.notice")
        default:
            EmptyView()
        }
    }
}

private extension View {
    func fieldStyle() -> some View {
        self
            .font(DS.Typography.body)
            .padding(.horizontal, DS.Spacing.md)
            .frame(minHeight: 50)
            .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).strokeBorder(DS.Colors.separator, lineWidth: 1))
    }
}
#endif
