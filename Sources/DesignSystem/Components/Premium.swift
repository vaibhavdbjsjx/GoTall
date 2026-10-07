#if os(iOS)
import SwiftUI
import GrowthCore

// Premium components. Same Spruce surfaces, type and motion as the rest of the app: Premium reads as a
// deeper layer of the product, not a different one. No gold, no gradients that shout, no countdowns.

/// Quiet outline label marking a Premium feature.
public struct PremiumBadge: View {
    let text: String
    public init(_ text: String = "Premium") { self.text = text }

    public var body: some View {
        Text(text)
            .font(DS.Typography.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.vertical, 3)
            .foregroundStyle(DS.Colors.accent)
            .overlay(Capsule().strokeBorder(DS.Colors.accent.opacity(0.55), lineWidth: 1))
            .accessibilityLabel("\(text) feature")
    }
}

/// A row describing one feature, used in Profile and in "what stays free" lists.
public struct PremiumFeatureRow: View {
    let symbol: String
    let title: String
    let detail: String
    let trailing: String?

    public init(symbol: String, title: String, detail: String, trailing: String? = nil) {
        self.symbol = symbol
        self.title = title
        self.detail = detail
        self.trailing = trailing
    }

    public var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(DS.Colors.accent)
                .frame(width: 28)
                .accessibilityHidden(true)
                .hiddenAtAccessibilitySizes()
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                Text(detail).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let trailing { Badge(trailing) }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A benefit on the paywall: what you get and why it's useful.
public struct BenefitCard: View {
    let symbol: String
    let title: String
    let detail: String
    let tag: String?

    public init(symbol: String, title: String, detail: String, tag: String? = nil) {
        self.symbol = symbol
        self.title = title
        self.detail = detail
        self.tag = tag
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
            VStack(alignment: .leading, spacing: 3) {
                AdaptiveStack(horizontalAlignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                    Text(title).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                    if let tag { Badge(tag) }
                }
                Text(detail).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsSurface()
        .accessibilityElement(children: .combine)
    }
}

/// An abstract miniature of the doctor-ready report: page, header, chart with percentile curves and a table.
/// Illustrative only (no numbers), so it can never be mistaken for someone's data.
public struct ReportPreview: View {
    let compact: Bool
    public init(compact: Bool = false) { self.compact = compact }

    public var body: some View {
        let w: CGFloat = compact ? 92 : 132
        let h = w * 1.29
        ZStack {
            page(width: w, height: h)
                .rotationEffect(.degrees(-5))
                .offset(x: -w * 0.16, y: 6)
                .opacity(0.55)
            page(width: w, height: h)
                .rotationEffect(.degrees(3))
                .offset(x: w * 0.12)
        }
        .frame(width: w * 1.5, height: h + 16)
        .accessibilityHidden(true)
    }

    private func page(width w: CGFloat, height h: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: w * 0.05) {
            Capsule().fill(DS.Colors.accent).frame(width: w * 0.34, height: w * 0.035)
            Capsule().fill(DS.Colors.textPrimary.opacity(0.75)).frame(width: w * 0.62, height: w * 0.06)
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(DS.Colors.accentSoft.opacity(0.7))
                Canvas { context, size in
                    for (i, offset) in [0.18, 0.34, 0.5, 0.66, 0.82].enumerated() {
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: size.height * (offset + 0.1)))
                        path.addQuadCurve(to: CGPoint(x: size.width, y: size.height * (offset - 0.16)),
                                          control: CGPoint(x: size.width * 0.5, y: size.height * (offset - 0.02)))
                        context.stroke(path, with: .color(.gray.opacity(i == 2 ? 0.6 : 0.3)), lineWidth: i == 2 ? 1 : 0.6)
                    }
                    var line = Path()
                    line.move(to: CGPoint(x: size.width * 0.12, y: size.height * 0.72))
                    line.addLine(to: CGPoint(x: size.width * 0.38, y: size.height * 0.6))
                    line.addLine(to: CGPoint(x: size.width * 0.62, y: size.height * 0.5))
                    line.addLine(to: CGPoint(x: size.width * 0.8, y: size.height * 0.44))
                    context.stroke(line, with: .color(Color(red: 0.035, green: 0.44, blue: 0.37)), lineWidth: 1.6)
                }
                .padding(3)
            }
            .frame(height: h * 0.36)
            ForEach(0..<4, id: \.self) { i in
                HStack(spacing: w * 0.04) {
                    Capsule().fill(DS.Colors.separator).frame(width: w * 0.24, height: w * 0.025)
                    Capsule().fill(DS.Colors.separator).frame(width: w * (i.isMultiple(of: 2) ? 0.3 : 0.22), height: w * 0.025)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(w * 0.09)
        .frame(width: w, height: h, alignment: .topLeading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 6)
        .environment(\.colorScheme, .light)
    }
}

/// Paywall header: the report miniature, the promise, and the reassurance that the core stays free.
public struct PaywallHero: View {
    let title: String
    let subtitle: String

    public init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(spacing: DS.Spacing.md) {
            ReportPreview()
                .hiddenAtAccessibilitySizes()
            VStack(spacing: DS.Spacing.xs) {
                PremiumBadge()
                Text(title)
                    .font(DS.Typography.display)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("paywall.title")
                Text(subtitle)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// One selectable plan. Price and billing period are always shown in full, at the same size for every plan.
public struct PriceOption: View {
    let plan: SubscriptionPlan
    let detail: String?
    let tag: String?
    let isSelected: Bool
    let action: () -> Void

    public init(plan: SubscriptionPlan, detail: String?, tag: String?, isSelected: Bool, action: @escaping () -> Void) {
        self.plan = plan
        self.detail = detail
        self.tag = tag
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: DS.Spacing.md) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? DS.Colors.accent : DS.Colors.separator)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    AdaptiveStack(horizontalAlignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                        Text(plan.period == .year ? "Yearly" : "Monthly")
                            .font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                        if let tag { Badge(tag, tone: .accent) }
                    }
                    Text(plan.priceLine)
                        .font(DS.Typography.body.weight(.semibold).monospacedDigit())
                        .foregroundStyle(DS.Colors.textPrimary)
                    if let detail {
                        Text(detail).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(isSelected ? DS.Colors.accent : DS.Colors.separator, lineWidth: isSelected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("plan.\(plan.period.rawValue)")
    }
}

/// Primary purchase action. The title always contains the price and period.
public struct PurchaseButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    public init(title: String, isLoading: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        AppButton(title, kind: .primary, isLoading: isLoading, action: action)
            .accessibilityIdentifier("paywall.purchase")
    }
}

public struct RestorePurchaseButton: View {
    let isLoading: Bool
    let action: () -> Void

    public init(isLoading: Bool, action: @escaping () -> Void) {
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        AppButton("Restore purchases", kind: .tertiary, isLoading: isLoading, fullWidth: false, action: action)
            .accessibilityIdentifier("paywall.restore")
    }
}

/// Row that opens Apple's subscription management sheet.
public struct ManageSubscriptionRow: View {
    let action: () -> Void
    public init(action: @escaping () -> Void) { self.action = action }

    public var body: some View {
        Button(action: action) {
            HStack {
                Label("Manage subscription", systemImage: "creditcard").foregroundStyle(DS.Colors.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right").font(.footnote.weight(.semibold)).foregroundStyle(DS.Colors.textTertiary)
            }
        }
        .accessibilityHint("Opens Apple's subscription settings")
        .accessibilityIdentifier("profile.manageSubscription")
    }
}

/// Subscription status at the top of Profile.
public struct SubscriptionCard: View {
    let title: String
    let detail: String
    let isPremium: Bool
    let actionTitle: String?
    let action: (() -> Void)?

    public init(title: String, detail: String, isPremium: Bool, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.detail = detail
        self.isPremium = isPremium
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: isPremium ? "checkmark.seal.fill" : "doc.richtext")
                    .font(.title2)
                    .foregroundStyle(DS.Colors.accent)
                    .frame(width: 44, height: 44)
                    .background(DS.Colors.accentSoft, in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    .accessibilityHidden(true)
                    .hiddenAtAccessibilitySizes()
                VStack(alignment: .leading, spacing: 3) {
                    AdaptiveStack(horizontalAlignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                        Text(title).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                        if isPremium { Badge("Active", tone: .accent) }
                    }
                    Text(detail).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            if let actionTitle, let action {
                AppButton(actionTitle, kind: .secondary, action: action)
                    .accessibilityIdentifier("premium.explore")
            }
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsSurface()
        .accessibilityElement(children: .contain)
    }
}

/// A Premium feature shown, not hidden: a clearly labelled preview built from real data, what Premium adds,
/// and a calm way to learn more.
public struct LockedFeaturePreview<Preview: View>: View {
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void
    let preview: Preview

    public init(title: String, message: String, buttonTitle: String = "Explore Premium", action: @escaping () -> Void, @ViewBuilder preview: () -> Preview) {
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.action = action
        self.preview = preview()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            AdaptiveStack(horizontalAlignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                Text(title).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0).hiddenAtAccessibilitySizes()
                PremiumBadge()
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("PREVIEW · FROM YOUR MEASUREMENTS")
                    .font(DS.Typography.eyebrow)
                    .foregroundStyle(DS.Colors.textTertiary)
                preview
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Colors.surfaceSecondary.opacity(0.7), in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .accessibilityElement(children: .combine)
            Text(message).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            AppButton(buttonTitle, kind: .secondary, action: action)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsSurface()
    }
}
#endif
