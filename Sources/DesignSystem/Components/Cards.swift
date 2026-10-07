#if os(iOS)
import SwiftUI

/// Base surface for grouped content.
public struct AppCard<Content: View>: View {
    let padding: CGFloat
    let content: Content

    public init(padding: CGFloat = DS.Spacing.md, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .dsSurface()
    }
}

public struct SectionHeader: View {
    let title: String
    let actionTitle: String?
    let action: (() -> Void)?

    public init(_ title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(DS.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(DS.Colors.accent)
                    .frame(minHeight: DS.minimumTapTarget)
            }
        }
    }
}

/// A labelled value with an optional caption. Numbers animate between values.
public struct MetricCard: View {
    let label: String
    let value: String?
    let caption: String?
    let systemImage: String
    let placeholder: String
    let accessibilityValue: String?

    public init(label: String, value: String?, caption: String? = nil, systemImage: String, placeholder: String = "Not yet", accessibilityValue: String? = nil) {
        self.label = label
        self.value = value
        self.caption = caption
        self.systemImage = systemImage
        self.placeholder = placeholder
        self.accessibilityValue = accessibilityValue
    }

    public var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Label(label, systemImage: systemImage)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                if let value {
                    Text(value)
                        .font(DS.Typography.metricSmall)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .contentTransition(.numericText())
                } else {
                    Text(placeholder)
                        .font(DS.Typography.callout)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                if let caption {
                    Text(caption)
                        .font(DS.Typography.footnote)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue([accessibilityValue ?? value ?? placeholder, caption].compactMap { $0 }.joined(separator: ". "))
    }
}

public struct MeasurementRow: View {
    let value: String
    let accessibleValue: String
    let date: String
    let detail: String?

    public init(value: String, accessibleValue: String, date: String, detail: String? = nil) {
        self.value = value
        self.accessibleValue = accessibleValue
        self.date = date
        self.detail = detail
    }

    public var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(date)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Colors.textPrimary)
                if let detail {
                    Text(detail)
                        .font(DS.Typography.footnote)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
            Spacer(minLength: DS.Spacing.sm)
            Text(value)
                .font(DS.Typography.metricSmall)
                .foregroundStyle(DS.Colors.textPrimary)
        }
        .padding(.vertical, DS.Spacing.xs)
        .frame(minHeight: DS.minimumTapTarget)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(date), \(accessibleValue)")
        .accessibilityValue(detail ?? "")
    }
}

public struct Badge: View {
    public enum Tone: Sendable { case neutral, accent, warm, caution }
    let text: String
    let tone: Tone

    public init(_ text: String, tone: Tone = .neutral) {
        self.text = text
        self.tone = tone
    }

    public var body: some View {
        Text(text)
            .font(DS.Typography.caption)
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.vertical, 4)
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
    }

    private var foreground: Color {
        switch tone {
        case .neutral: return DS.Colors.textSecondary
        case .accent: return DS.Colors.accent
        case .warm: return DS.Colors.warm
        case .caution: return DS.Colors.caution
        }
    }

    private var background: Color {
        switch tone {
        case .neutral: return DS.Colors.surfaceSecondary
        case .accent: return DS.Colors.accentSoft
        case .warm: return DS.Colors.warmSoft
        case .caution: return DS.Colors.cautionSoft
        }
    }
}
#endif
