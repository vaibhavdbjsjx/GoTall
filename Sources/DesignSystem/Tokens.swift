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

    /// "Midnight": deep ink, never pure black.
    public var background = Pair(0xF7F4EE, 0x0B0F1A)
    public var surface = Pair(0xFFFFFF, 0x151B2A)
    public var surfaceSecondary = Pair(0xEFEADF, 0x1C2334)
    public var separator = Pair(0xE4DDCF, 0x283045)
    public var textPrimary = Pair(0x14161C, 0xF4F1EA)
    public var textSecondary = Pair(0x5A5F6B, 0xA3ABBD)
    public var textTertiary = Pair(0x60656F, 0x8A93A6)
    /// "Champagne": the one accent. Soft gold on midnight, deep antique gold on ivory (both ≥ 4.5:1).
    public var accent = Pair(0x8A6418, 0xE8C77A)
    public var onAccent = Pair(0xFFFFFF, 0x1A1406)
    public var accentSoft = Pair(0xF3E8CF, 0x2A2618)
    /// Calm teal for progress and "on track" moments, used sparingly next to the gold.
    public var warm = Pair(0x0F6B5C, 0x7FD1C0)
    public var warmSoft = Pair(0xDDEFEA, 0x13302C)
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
        /// Hero titles use the serif design for an editorial, premium feel (matches the website's Instrument Serif).
        public static let display = Font.system(.largeTitle, design: .serif).weight(.regular)
        /// Big serif numbers for hero moments (the height reveal, the posture score).
        public static let heroNumber = Font.system(size: 64, weight: .regular, design: .serif).monospacedDigit()
        /// Onboarding questions: big enough to lead, smaller than `display` so long questions stay readable.
        public static let question = Font.system(.title, design: .serif).weight(.regular)
        public static let title = Font.system(.title2, design: .serif).weight(.regular)
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

/// Light mode: soft shadow + hairline. Dark mode: no shadow (it reads as mud); a lighter surface, a faint top-lit
/// sheen and a hairline instead, so cards read as glass on midnight.
struct SurfaceElevation: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var radius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(DS.Colors.surface, in: shape)
            .overlay {
                if colorScheme == .dark {
                    shape.fill(LinearGradient(colors: [.white.opacity(0.045), .clear], startPoint: .top, endPoint: .center))
                        .allowsHitTesting(false)
                }
            }
            .overlay(
                shape.strokeBorder(
                    colorScheme == .dark
                        ? AnyShapeStyle(LinearGradient(colors: [.white.opacity(0.12), .white.opacity(0.03)], startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(DS.Colors.separator.opacity(0.7)),
                    lineWidth: 0.6)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 10, x: 0, y: 3)
    }
}

/// The page backdrop: midnight with a faint champagne glow at the top in dark mode, plain ivory in light mode.
public struct PageBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        ZStack(alignment: .top) {
            DS.Colors.background
            if colorScheme == .dark {
                RadialGradient(colors: [DS.Colors.accent.opacity(0.10), .clear], center: .top, startRadius: 0, endRadius: 420)
                    .frame(height: 520)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }
}

public extension View {
    func dsSurface(radius: CGFloat = DS.Radius.lg) -> some View {
        modifier(SurfaceElevation(radius: radius))
    }

    func dsPageBackground() -> some View {
        background(PageBackdrop())
    }
}
#endif
