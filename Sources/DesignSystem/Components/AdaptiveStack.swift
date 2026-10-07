#if os(iOS)
import SwiftUI

/// Horizontal at normal text sizes, vertical at accessibility sizes, so side-by-side content never
/// squeezes into hyphenated fragments (found in simulator screenshots at AX sizes).
public struct AdaptiveStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let horizontalAlignment: VerticalAlignment
    let spacing: CGFloat
    let content: Content

    public init(horizontalAlignment: VerticalAlignment = .center, spacing: CGFloat = DS.Spacing.sm, @ViewBuilder content: () -> Content) {
        self.horizontalAlignment = horizontalAlignment
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: spacing) { content }
        } else {
            HStack(alignment: horizontalAlignment, spacing: spacing) { content }
        }
    }
}

public extension View {
    /// Hides decorative icons at accessibility text sizes to give text the full width.
    func hiddenAtAccessibilitySizes() -> some View {
        modifier(HideAtAccessibilitySizes())
    }
}

struct HideAtAccessibilitySizes: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    func body(content: Content) -> some View {
        if dynamicTypeSize.isAccessibilitySize { EmptyView() } else { content }
    }
}
#endif
