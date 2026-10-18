import Foundation

/// Single source of truth for product identity. Every user-facing reference to the product name reads from
/// `BrandConfig.current`; the build setting `APP_DISPLAY_NAME` in App/project.yml must match `displayName`.
///
/// Name: **Linden** (the linden tree: tall, steady growth, heart-shaped leaf). Chosen in the release pass;
/// trademark, domain and App Store name availability still have to be checked before submission.
public struct BrandConfig: Sendable, Equatable {
    /// Name shown in UI copy ("Welcome to …").
    public var displayName: String
    /// One-line promise used on the welcome screen. Must never promise height gain.
    public var tagline: String
    /// Name of the on-device assistant.
    public var assistantName: String
    /// Hosted privacy policy (the same text is also shown in the app, so it works offline).
    public var privacyPolicyURL: URL?
    public var termsURL: URL?
    /// Support page required by App Store Connect.
    public var supportURL: URL?
    /// Support contact. `nil` until a real address exists (set before submission).
    public var supportEmail: String?

    public init(displayName: String, tagline: String, assistantName: String, privacyPolicyURL: URL?, termsURL: URL?,
                supportURL: URL?, supportEmail: String?) {
        self.displayName = displayName
        self.tagline = tagline
        self.assistantName = assistantName
        self.privacyPolicyURL = privacyPolicyURL
        self.termsURL = termsURL
        self.supportURL = supportURL
        self.supportEmail = supportEmail
    }

    /// Release brand. The URLs point at the static pages in `site/` once they are published
    /// (GitHub Pages or any static host; see docs/release-checklist.md).
    public static let linden = BrandConfig(
        displayName: "Linden",
        tagline: "Growth, beautifully understood.",
        assistantName: "Ask Linden",
        privacyPolicyURL: URL(string: "https://vaibhavdbjsjx.github.io/linden/privacy.html"),
        termsURL: URL(string: "https://vaibhavdbjsjx.github.io/linden/terms.html"),
        supportURL: URL(string: "https://vaibhavdbjsjx.github.io/linden/support.html"),
        supportEmail: nil
    )

    public static let current: BrandConfig = .linden
}
