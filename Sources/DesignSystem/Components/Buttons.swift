#if os(iOS)
import SwiftUI

public enum AppButtonKind: Sendable {
    case primary
    case secondary
    case tertiary
    case destructive
}

/// The one button component. Full width by default, minimum 50 pt tall, supports a loading state.
public struct AppButton: View {
    let title: String
    let systemImage: String?
    let kind: AppButtonKind
    let isLoading: Bool
    let fullWidth: Bool
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    public init(_ title: String, systemImage: String? = nil, kind: AppButtonKind = .primary, isLoading: Bool = false, fullWidth: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.kind = kind
        self.isLoading = isLoading
        self.fullWidth = fullWidth
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                if isLoading {
                    ProgressView().tint(foreground)
                } else if let systemImage {
                    Image(systemName: systemImage).imageScale(.medium)
                }
                Text(title).font(DS.Typography.headline)
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(minHeight: kind == .tertiary ? DS.minimumTapTarget : 50)
            .padding(.horizontal, kind == .tertiary ? DS.Spacing.xs : DS.Spacing.lg)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .disabled(isLoading)
        .accessibilityLabel(isLoading ? "\(title), in progress" : title)
    }

    private var foreground: Color {
        switch kind {
        case .primary: return isEnabled ? DS.Colors.onAccent : DS.Colors.textTertiary
        case .secondary: return isEnabled ? DS.Colors.accent : DS.Colors.textTertiary
        case .tertiary: return isEnabled ? DS.Colors.accent : DS.Colors.textTertiary
        case .destructive: return DS.Colors.danger
        }
    }

    private var background: Color {
        switch kind {
        case .primary: return isEnabled ? DS.Colors.accent : DS.Colors.surfaceSecondary
        case .secondary: return DS.Colors.accentSoft
        case .tertiary: return .clear
        case .destructive: return DS.Colors.danger.opacity(0.12)
        }
    }
}
#endif
