#if os(iOS)
import SwiftUI

/// Restrained motion. Every animation is short, interruptible and has a Reduce Motion fallback.
public enum Motion {
    /// Selection feedback, toggles.
    public static let quick = Animation.easeOut(duration: 0.18)
    /// Default for layout and card changes.
    public static let standard = Animation.spring(response: 0.35, dampingFraction: 0.9)
    /// Page/step transitions.
    public static let page = Animation.spring(response: 0.42, dampingFraction: 0.92)
    /// Progress bars.
    public static let progress = Animation.easeInOut(duration: 0.45)
    /// Reveal moments (summary, later the estimate). Still under half a second.
    public static let reveal = Animation.spring(response: 0.5, dampingFraction: 0.86)

    /// Under Reduce Motion: no movement, a brief cross-fade only.
    public static func resolved(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.15) : animation
    }

    /// Direction-aware step transition: forward slides in from the trailing edge, back from the leading edge.
    public static func stepTransition(forward: Bool, reduceMotion: Bool) -> AnyTransition {
        if reduceMotion { return .opacity }
        let insertion: AnyTransition = .move(edge: forward ? .trailing : .leading).combined(with: .opacity)
        let removal: AnyTransition = .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
        return .asymmetric(insertion: insertion, removal: removal)
    }
}

/// Fades and lifts content in once, on first appearance. Disabled under Reduce Motion.
struct AppearEffect: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false
    var delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(visible || reduceMotion ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 8)
            .onAppear {
                guard !reduceMotion, !visible else { return }
                withAnimation(Motion.standard.delay(delay)) { visible = true }
            }
    }
}

public extension View {
    /// Use for cards entering a screen. Stagger with small delays (≤ 0.15 s total).
    func appearEffect(delay: Double = 0) -> some View {
        modifier(AppearEffect(delay: delay))
    }
}

/// Subtle press feedback for tappable cards and buttons.
public struct PressableStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        PressableBody(configuration: configuration)
    }

    struct PressableBody: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        let configuration: ButtonStyleConfiguration
        var body: some View {
            configuration.label
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
                .opacity(configuration.isPressed ? 0.92 : 1)
                .animation(Motion.quick, value: configuration.isPressed)
        }
    }
}
#endif
