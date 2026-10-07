import Foundation

/// Single source of truth for product identity.
///
/// The final name has not been chosen (see docs/launch-strategy.md §3). Every user-facing
/// reference to the product name must read from `BrandConfig.current`, so renaming the app
/// is a one-line change here plus the `APP_DISPLAY_NAME` build setting in App/project.yml.
public struct BrandConfig: Sendable, Equatable {
    /// Name shown in UI copy ("Welcome to …").
    public var displayName: String
    /// One-line promise used on the welcome screen. Must never promise height gain.
    public var tagline: String
    /// Full privacy policy URL. `nil` until the policy is published (Phase 11).
    public var privacyPolicyURL: URL?
    /// Support contact. `nil` until a real address exists.
    public var supportEmail: String?

    public init(displayName: String, tagline: String, privacyPolicyURL: URL?, supportEmail: String?) {
        self.displayName = displayName
        self.tagline = tagline
        self.privacyPolicyURL = privacyPolicyURL
        self.supportEmail = supportEmail
    }

    /// Internal working title. Not a final brand decision.
    public static let workingTitle = BrandConfig(
        displayName: "Arcwise",
        tagline: "Understand growth, honestly.",
        privacyPolicyURL: nil,
        supportEmail: nil
    )

    public static let current: BrandConfig = .workingTitle
}
