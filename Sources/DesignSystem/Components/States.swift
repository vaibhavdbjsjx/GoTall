#if os(iOS)
import SwiftUI

public struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    public init(systemImage: String, title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(.title, design: .rounded))
                .foregroundStyle(DS.Colors.accent)
                .frame(width: 56, height: 56)
                .background(DS.Colors.accentSoft, in: Circle())
                .accessibilityHidden(true)
            Text(title)
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(DS.Typography.subheadline)
                .foregroundStyle(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                AppButton(actionTitle, kind: .secondary, fullWidth: false, action: action)
                    .padding(.top, DS.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.xl)
        .accessibilityElement(children: .combine)
    }
}

public struct LoadingStateView: View {
    let message: String

    public init(_ message: String = "Loading") {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            ProgressView()
            Text(message)
                .font(DS.Typography.subheadline)
                .foregroundStyle(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

public struct ErrorStateView: View {
    let title: String
    let message: String
    let primaryTitle: String
    let primaryAction: () -> Void
    let secondaryTitle: String?
    let secondaryAction: (() -> Void)?

    public init(title: String, message: String, primaryTitle: String, primaryAction: @escaping () -> Void, secondaryTitle: String? = nil, secondaryAction: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.primaryTitle = primaryTitle
        self.primaryAction = primaryAction
        self.secondaryTitle = secondaryTitle
        self.secondaryAction = secondaryAction
    }

    public var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(.title, design: .rounded))
                .foregroundStyle(DS.Colors.caution)
                .accessibilityHidden(true)
            Text(title)
                .font(DS.Typography.title)
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
            AppButton(primaryTitle, action: primaryAction)
            if let secondaryTitle, let secondaryAction {
                AppButton(secondaryTitle, kind: .tertiary, action: secondaryAction)
            }
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: 520)
    }
}

public struct InfoBanner: View {
    public enum Tone: Sendable { case info, caution, success }
    let tone: Tone
    let title: String?
    let message: String

    public init(_ message: String, title: String? = nil, tone: Tone = .info) {
        self.tone = tone
        self.title = title
        self.message = message
    }

    public var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: symbol)
                .foregroundStyle(foreground)
                .font(.body.weight(.semibold))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                if let title {
                    Text(title).font(DS.Typography.subheadline.weight(.semibold)).foregroundStyle(DS.Colors.textPrimary)
                }
                Text(message)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.sm)
        .background(background, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch tone {
        case .info: return "info.circle"
        case .caution: return "exclamationmark.circle"
        case .success: return "checkmark.circle"
        }
    }

    private var foreground: Color {
        switch tone {
        case .info, .success: return DS.Colors.accent
        case .caution: return DS.Colors.caution
        }
    }

    private var background: Color {
        switch tone {
        case .info, .success: return DS.Colors.accentSoft
        case .caution: return DS.Colors.cautionSoft
        }
    }
}

/// Short, plain-language privacy statement with an icon. Used in onboarding and Profile.
public struct PrivacyNotice: View {
    let items: [(symbol: String, title: String, detail: String)]

    public init(items: [(symbol: String, title: String, detail: String)]) {
        self.items = items
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                FeatureRow(symbol: item.symbol, title: item.title, detail: item.detail)
                    .appearEffect(delay: Double(index) * 0.04)
            }
        }
    }
}

/// Icon + title + detail. Used for value propositions and privacy points.
public struct FeatureRow: View {
    let symbol: String
    let title: String
    let detail: String

    public init(symbol: String, title: String, detail: String) {
        self.symbol = symbol
        self.title = title
        self.detail = detail
    }

    public var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: symbol)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(DS.Colors.accent)
                .frame(width: 40, height: 40)
                .background(DS.Colors.accentSoft, in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                .accessibilityHidden(true)
                .hiddenAtAccessibilitySizes()
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.textPrimary)
                Text(detail)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
#endif
