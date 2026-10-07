#if os(iOS)
import SwiftUI
import UIKit

/// Brand colours as light/dark hex pairs. Rebranding = editing this one struct.
/// Every text/background pair has been checked for WCAG AA (≥ 4.5:1); see docs/phase-2-foundation.md.
public struct BrandPalette: Sendable {
    public struct Pair: Sendable {
        public var light: UInt32
        public var dark: UInt32
        public init(_ light: UInt32, _ dark: UInt32) { self.light = light; self.dark = dark }
    }

    public var background = Pair(0xF6F5F1, 0x0D1012)
    public var surface = Pair(0xFFFFFF, 0x161A1D)
    public var surfaceSecondary = Pair(0xEEECE6, 0x1F2427)
    public var separator = Pair(0xE2DFD8, 0x2A3034)
    public var textPrimary = Pair(0x15191B, 0xF1F3F2)
    public var textSecondary = Pair(0x565F63, 0xA7B0B4)
    public var textTertiary = Pair(0x5F686C, 0x8E979B)
    /// "Spruce": calm, confident green-teal. Distinct from medical blue and fitness neon.
    public var accent = Pair(0x09705F, 0x45C7AC)
    public var onAccent = Pair(0xFFFFFF, 0x06201B)
    public var accentSoft = Pair(0xDCEFEA, 0x12332D)
    /// Warm secondary accent, used sparingly for highlights (never for warnings).
    public var warm = Pair(0xA84F25, 0xF0A46E)
    public var warmSoft = Pair(0xF8E9DF, 0x33231A)
    /// Caution is amber, never red: growth data is never framed as alarming.
    public var caution = Pair(0x8F5B00, 0xE9B04F)
    public var cautionSoft = Pair(0xFBF0DC, 0x2E2414)
    public var danger = Pair(0xB3261E, 0xF2B8B5)

    public static let current = BrandPalette()
}

public enum DS {
    // MARK: Colour

    public enum Colors {
        static let palette = BrandPalette.current

        static func dynamic(_ pair: BrandPalette.Pair) -> Color {
            Color(UIColor { traits in
                UIColor(hex: traits.userInterfaceStyle == .dark ? pair.dark : pair.light)
            })
        }

        public static let background = dynamic(palette.background)
        public static let surface = dynamic(palette.surface)
        public static let surfaceSecondary = dynamic(palette.surfaceSecondary)
        public static let separator = dynamic(palette.separator)
        public static let textPrimary = dynamic(palette.textPrimary)
        public static let textSecondary = dynamic(palette.textSecondary)
        public static let textTertiary = dynamic(palette.textTertiary)
        public static let accent = dynamic(palette.accent)
        public static let onAccent = dynamic(palette.onAccent)
        public static let accentSoft = dynamic(palette.accentSoft)
        public static let warm = dynamic(palette.warm)
        public static let warmSoft = dynamic(palette.warmSoft)
        public static let caution = dynamic(palette.caution)
        public static let cautionSoft = dynamic(palette.cautionSoft)
        public static let danger = dynamic(palette.danger)
    }

    // MARK: Spacing (4-pt grid)

    public enum Spacing {
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 8
        public static let sm: CGFloat = 12
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 20
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
        public static let xxxl: CGFloat = 40
        /// Horizontal page margin.
        public static let page: CGFloat = 20
    }

    // MARK: Radius (continuous corners)

    public enum Radius {
        public static let sm: CGFloat = 10
        public static let md: CGFloat = 14
        public static let lg: CGFloat = 20
        public static let xl: CGFloat = 28
    }

    /// Minimum tap target (Apple HIG).
    public static let minimumTapTarget: CGFloat = 44

    // MARK: Typography
    // Built on Dynamic Type text styles so every size scales with the user's setting.

    public enum Typography {
        public static let display = Font.system(.largeTitle, design: .default).weight(.bold)
        /// Onboarding questions: big enough to lead, smaller than `display` so long questions stay readable.
        public static let question = Font.system(.title, design: .default).weight(.bold)
        public static let title = Font.system(.title2, design: .default).weight(.semibold)
        public static let headline = Font.system(.headline, design: .default)
        public static let body = Font.system(.body)
        public static let callout = Font.system(.callout)
        public static let subheadline = Font.system(.subheadline)
        public static let footnote = Font.system(.footnote)
        public static let caption = Font.system(.caption).weight(.medium)
        /// Eyebrow labels above titles ("PROFILE · 2 OF 5").
        public static let eyebrow = Font.system(.caption, design: .default).weight(.semibold)
        /// Numbers: rounded, monospaced digits so values don't jitter while changing.
        public static let metricLarge = Font.system(.largeTitle, design: .rounded).weight(.semibold).monospacedDigit()
        public static let metric = Font.system(.title, design: .rounded).weight(.semibold).monospacedDigit()
        public static let metricSmall = Font.system(.title3, design: .rounded).weight(.semibold).monospacedDigit()
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: Elevation

/// Light mode: soft shadow + hairline. Dark mode: no shadow (it reads as mud); a lighter surface and hairline instead.
struct SurfaceElevation: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(DS.Colors.separator.opacity(colorScheme == .dark ? 1 : 0.7), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 10, x: 0, y: 3)
    }
}

public extension View {
    func dsSurface(radius: CGFloat = DS.Radius.lg) -> some View {
        modifier(SurfaceElevation(radius: radius))
    }

    func dsPageBackground() -> some View {
        background(DS.Colors.background.ignoresSafeArea())
    }
}
#endif
