import Foundation

/// Single source of truth for product identity. Every user-facing reference to the product name reads from
/// `BrandConfig.current`; the build setting `APP_DISPLAY_NAME` in App/project.yml must match `displayName`.
///
/// Name: **Stature** ("Stature: Height & Growth" on the App Store). Trademark and App Store name availability
/// still have to be checked before submission (docs/release-checklist.md).
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

    /// Release brand. The URLs point at the marketing site (`/mnt/project-files/website/stature-site`, hosted on
    /// Netlify). Update them here and in docs/app-store-listing.md if the site moves to a custom domain.
    public static let stature = BrandConfig(
        displayName: "Stature",
        tagline: "Growth, measured honestly. Habits that help you stand tall.",
        assistantName: "Stature Coach",
        privacyPolicyURL: URL(string: "https://stature.netlify.app/privacy"),
        termsURL: URL(string: "https://stature.netlify.app/terms"),
        supportURL: URL(string: "https://stature.netlify.app/support"),
        supportEmail: "support@stature.app"
    )

    /// Name of the subscription as people see it ("Stature Pro"). Matches the website and App Store Connect.
    public static let premiumName = "Stature Pro"

    public static let current: BrandConfig = .stature
}
