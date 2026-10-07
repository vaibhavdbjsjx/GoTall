#if os(iOS)
import SwiftUI
import GrowthCore
import DesignSystem

/// The Premium page. Answers "why pay?" before "how much?", shows every price and billing term in full,
/// keeps the close button visible at all times, and never uses urgency, timers or pre-selected trials.
struct PaywallView: View {
    let context: PaywallContext
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.openURL) private var openURL
    @State private var model: PaywallModel?
    @State private var showsPrivacy = false

    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    if model.purchase == .succeeded || (entitlements.isPremium && model.purchase == .idle) {
                        PremiumActiveView(justPurchased: model.purchase == .succeeded) { dismiss() }
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        content(model)
                    }
                } else {
                    Color.clear
                }
            }
            .animation(Motion.standard, value: model?.purchase)
            .dsPageBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(DS.Colors.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(DS.Colors.surfaceSecondary, in: Circle())
                    }
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("paywall.close")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showsPrivacy) { PrivacySummaryView() }
        }
        .task {
            if model == nil {
                let created = PaywallModel(store: entitlements)
                model = created
                await created.loadPlans()
                #if DEBUG
                if UserDefaults.standard.bool(forKey: "paywallAutoPurchase") { await created.purchaseSelected() }
                #endif
            }
        }
    }

    @ViewBuilder
    private func content(_ model: PaywallModel) -> some View {
        let pinned = !dynamicTypeSize.isAccessibilitySize
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                PaywallHero(title: "Go deeper with your growth profile.",
                            subtitle: "Your growth result, chart, estimate and history stay free. Premium adds tools for following growth over the years and sharing it with a doctor.")
                    .padding(.top, DS.Spacing.xs)
                if let intro = context.intro {
                    InfoBanner(intro, tone: .info)
                }
                benefits
                alwaysFree
                plans(model)
                terms(model)
                if !pinned { purchaseArea(model) }
            }
            .padding(.horizontal, DS.Spacing.page)
            .padding(.bottom, DS.Spacing.xl)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if pinned {
                purchaseArea(model)
                    .padding(.horizontal, DS.Spacing.page)
                    .padding(.top, DS.Spacing.sm)
                    .padding(.bottom, DS.Spacing.xs)
                    .background(.bar)
            }
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("What Premium adds").font(DS.Typography.title).foregroundStyle(DS.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            BenefitCard(symbol: "doc.richtext", title: "Doctor-ready growth report",
                        detail: "A clear PDF with the growth chart, every measurement, percentile history, methods and limitations. Made on your phone, ready for a check-up.")
            BenefitCard(symbol: "chart.line.uptrend.xyaxis", title: "Advanced growth analysis",
                        detail: "Percentile history over time, growth speed between measurements, and how the estimate has changed as you added data.")
            BenefitCard(symbol: "person.2", title: "Family profiles",
                        detail: "Follow more than one child in one place. Profiles you already have always stay yours to use.")
            BenefitCard(symbol: "square.stack.3d.up", title: "Future Premium tools", detail: "Planned additions, such as more report options, come with Premium.", tag: "Planned")
        }
    }

    private var alwaysFree: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Always free").font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            ForEach(["Height, percentile and growth chart", "Adult-height estimate and its explanation", "Unlimited measurement history",
                     "Habits, reminders, export and delete"], id: \.self) { item in
                Label {
                    Text(item).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                } icon: {
                    Image(systemName: "checkmark").font(.footnote.weight(.bold)).foregroundStyle(DS.Colors.accent)
                }
            }
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.surfaceSecondary.opacity(0.6), in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func plans(_ model: PaywallModel) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Choose a plan").font(DS.Typography.title).foregroundStyle(DS.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            switch model.plans {
            case .loading:
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .fill(DS.Colors.surfaceSecondary)
                        .frame(height: 84)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Loading prices")
            case .failed(let message):
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    InfoBanner(message, tone: .caution)
                    AppButton("Try again", systemImage: "arrow.clockwise", kind: .secondary) { Task { await model.loadPlans() } }
                }
                .accessibilityIdentifier("paywall.plansFailed")
            case .loaded(let plans):
                ForEach(plans) { plan in
                    PriceOption(plan: plan, detail: detail(for: plan, monthly: model.monthlyPlan),
                                tag: plan.savingPercent(comparedTo: model.monthlyPlan).map { "Save \($0)%" },
                                isSelected: plan.id == model.selectedPlan?.id) {
                        withAnimation(Motion.quick) { model.selectedPlanID = plan.id }
                        model.clearMessage()
                    }
                    .disabled(model.isBusy)
                }
            }
        }
    }

    private func detail(for plan: SubscriptionPlan, monthly: SubscriptionPlan?) -> String {
        var parts: [String] = []
        if let intro = plan.introductoryOffer { parts.append(intro) }
        if let equivalent = plan.monthlyEquivalent() {
            parts.append("Works out at \(equivalent) a month, billed once a year.")
        } else {
            parts.append("Billed every month. Cancel anytime.")
        }
        return parts.joined(separator: " ")
    }

    @ViewBuilder
    private func terms(_ model: PaywallModel) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if let plan = model.selectedPlan {
                Text(plan.billingTerms)
                    .font(DS.Typography.footnote)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("paywall.terms")
                if plan.isFamilyShareable {
                    Text("Family Sharing is on: up to five family members can use Premium at no extra cost.")
                        .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("Payment is handled by Apple. Your growth data stays on this device and is never sent to us to buy or check a subscription.")
                .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            AdaptiveStack(horizontalAlignment: .center, spacing: DS.Spacing.md) {
                Button("Terms of Use") { openURL(Self.termsURL) }
                Button("Privacy") {
                    if let url = BrandConfig.current.privacyPolicyURL { openURL(url) } else { showsPrivacy = true }
                }
                Spacer(minLength: 0).hiddenAtAccessibilitySizes()
                RestorePurchaseButton(isLoading: model.purchase == .restoring) { Task { await model.restore() } }
                    .disabled(model.isBusy)
            }
            .font(DS.Typography.footnote.weight(.semibold))
            .tint(DS.Colors.accent)
        }
    }

    @ViewBuilder
    private func purchaseArea(_ model: PaywallModel) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            if let message = model.statusMessage {
                Text(message)
                    .font(DS.Typography.footnote.weight(.medium))
                    .foregroundStyle(statusColor(model.purchase))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
                    .accessibilityIdentifier("paywall.status")
            }
            PurchaseButton(title: purchaseTitle(model), isLoading: model.isBusy && model.purchase != .restoring) {
                Task { await model.purchaseSelected() }
            }
            .disabled(model.selectedPlan == nil || model.isBusy)
        }
        .animation(Motion.quick, value: model.statusMessage)
        .onChange(of: model.statusMessage) { _, message in
            if let message { UIAccessibility.post(notification: .announcement, argument: message) }
        }
    }

    private func purchaseTitle(_ model: PaywallModel) -> String {
        if case .purchasing = model.purchase { return "Confirming with the App Store" }
        guard let plan = model.selectedPlan else { return "Subscribe" }
        if case .failed = model.purchase { return "Try again · \(plan.displayPrice)/\(plan.periodNoun)" }
        return "Subscribe · \(plan.displayPrice)/\(plan.periodNoun)"
    }

    private func statusColor(_ state: PaywallModel.PurchaseState) -> Color {
        switch state {
        case .failed: return DS.Colors.caution
        case .succeeded: return DS.Colors.accent
        default: return DS.Colors.textSecondary
        }
    }
}

extension View {
    /// Presents the paywall from the closest presentation context (works inside sheets too).
    func paywallSheet(_ context: Binding<PaywallContext?>) -> some View {
        sheet(item: context) { PaywallView(context: $0) }
    }
}

/// Shown after a purchase (or when Premium is already active): calm confirmation, then what's now available.
struct PremiumActiveView: View {
    let justPurchased: Bool
    let onDone: () -> Void
    @Environment(EntitlementStore.self) private var entitlements

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            SuccessSeal()
            VStack(spacing: DS.Spacing.xs) {
                Text(justPurchased ? "Premium is active" : "You have Premium")
                    .font(DS.Typography.title)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .accessibilityIdentifier("paywall.active")
                Text(entitlements.statusDescription())
                    .font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                PremiumFeatureRow(symbol: "doc.richtext", title: "Doctor-ready report", detail: "Profile › Reports, or from Growth.")
                PremiumFeatureRow(symbol: "chart.line.uptrend.xyaxis", title: "Advanced growth analysis", detail: "On the Growth tab.")
                PremiumFeatureRow(symbol: "person.2", title: "Family profiles", detail: "Add a child from the profile switcher.")
            }
            .padding(DS.Spacing.md)
            .dsSurface()
            Spacer()
            AppButton("Done", action: onDone)
                .accessibilityIdentifier("paywall.done")
        }
        .padding(DS.Spacing.page)
    }
}

/// Plain-language privacy summary, shown until the hosted privacy policy exists (BrandConfig.privacyPolicyURL).
struct PrivacySummaryView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    PrivacyNotice(items: [
                        ("iphone", "Stored on this device", "Profiles, measurements and habits are saved on this iPhone with file protection."),
                        ("creditcard", "Payments through Apple", "Apple processes subscriptions. We don't receive your payment details or send growth data anywhere to check a subscription."),
                        ("doc.richtext", "Reports made on the device", "PDF reports are created on this iPhone. You decide whether to share them."),
                        ("bell", "Reminders are local", "Notifications are scheduled on this iPhone. Nothing is sent to a server."),
                        ("hand.raised", "No ads, no tracking", "No advertising SDKs and no cross-app tracking."),
                        ("trash", "Export or delete anytime", "Profile › Privacy & data.")
                    ])
                }
                .padding(DS.Spacing.page)
            }
            .dsPageBackground()
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
#endif
