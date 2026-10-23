#if os(iOS)
import SwiftUI
import GrowthCore
import DesignSystem

/// The Gromax Pro page. Answers "why pay?" before "how much?", shows every price and billing term in full,
/// keeps the close button visible at all times, and never uses urgency, timers or pre-selected trials.
struct PaywallView: View {
    let context: PaywallContext
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var model: PaywallModel?
    @State private var legal: LegalDocument?

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
            .sheet(item: $legal) { LegalDocumentView(document: $0) }
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
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                PaywallHero(title: context == .onboarding ? "Your profile is ready. Want the full plan?" : "Better posture, better sleep, growth tracked properly.",
                            subtitle: "Your growth result, chart, estimate and history stay free. Gromax Pro adds the full routine library, weekly posture checks, the Outgrow Forecast and tools for sharing growth with a doctor.")
                    .padding(.top, DS.Spacing.xs)
                if let intro = context.intro {
                    InfoBanner(intro, tone: .info)
                }
                benefits
                alwaysFree
                plans(model)
                    .id("plans")
                terms(model)
                if !pinned { purchaseArea(model) }
            }
            .padding(.horizontal, DS.Spacing.page)
            .padding(.bottom, DS.Spacing.xl)
        }
        .onChange(of: model.loadedPlans.count) { _, count in
            #if DEBUG
            // Screenshot harness: `-paywallScrollTo plans`.
            if count > 0, let target = UserDefaults.standard.string(forKey: "paywallScrollTo") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { proxy.scrollTo(target, anchor: .top) }
            }
            #endif
        }
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
            Text("What Gromax Pro adds").font(DS.Typography.title).foregroundStyle(DS.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            BenefitCard(symbol: "figure.mind.and.body", title: "Every guided routine",
                        detail: "\(RoutineLibrary.all.count) routines and \(RoutineLibrary.moveCount) moves for posture, mobility and core, with a daily plan that adapts to your posture checks.")
            BenefitCard(symbol: "figure.stand", title: "Weekly posture checks",
                        detail: "A 30-second camera check of head, shoulder and hip alignment, with your score tracked week to week. Analysed on this iPhone; no image is kept.")
            BenefitCard(symbol: "tshirt", title: "Outgrow Forecast",
                        detail: "For children: expected height and clothing size over the next 3, 6 and 12 months, from their own growth curve.")
            BenefitCard(symbol: "doc.richtext", title: "Doctor-ready growth report",
                        detail: "A clear PDF with the growth chart, every measurement, percentile history, methods and limitations. Made on your phone, ready for a check-up.")
            BenefitCard(symbol: "chart.line.uptrend.xyaxis", title: "Advanced growth analysis",
                        detail: "Percentile history over time, growth speed between measurements, and how the estimate has changed as you added data.")
            BenefitCard(symbol: "person.2", title: "Family profiles",
                        detail: "Follow more than one child in one place. Profiles you already have always stay yours to use.")
            BenefitCard(symbol: "book", title: "The full Learn library",
                        detail: "Every article on growth, sleep, food and posture, each linked to its public-health source.")
            BenefitCard(symbol: "sparkles", title: "Unlimited \(BrandConfig.current.assistantName)",
                        detail: "Ask as many questions about growth as you like (3 a day are free). Answered privately on this iPhone: conversational on iPhones with Apple Intelligence, Gromax's built-in guide on others.")
        }
    }

    private var alwaysFree: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Always free").font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            ForEach(["Height, percentile and growth chart", "Adult-height estimate and its explanation", "Unlimited measurement history",
                     "Daily habits, bedtime planner and food variety", "Starter routines and your first posture check", "Reminders, export and delete"], id: \.self) { item in
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
                InfoBanner(message, title: "Prices aren't available", tone: .caution)
                    .accessibilityIdentifier("paywall.plansFailed")
            case .loaded(let plans):
                ForEach(plans) { plan in
                    PriceOption(plan: plan, detail: detail(for: plan, monthly: model.monthlyPlan),
                                tag: plan.savingPercent(comparedTo: model.monthlyPlan).map { "Save \($0)%" } ?? (plan.isLifetime ? "Best value" : nil),
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
        switch plan.period {
        case .year:
            if let equivalent = plan.monthlyEquivalent() { parts.append("Works out at \(equivalent) a month, billed once a year.") }
        case .month:
            parts.append("Billed every month. Cancel anytime.")
        case .week:
            if let year = plan.yearlyCost() { parts.append("Billed every week (\(year) over a year). Cancel anytime.") }
        case .lifetime:
            parts.append("Pay once, keep Gromax Pro for good. Nothing renews.")
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
                    Text("Family Sharing is on: up to five family members can use Gromax Pro at no extra cost.")
                        .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("Payment is handled by Apple. Your growth data stays on this device and is never sent to us to buy or check a subscription.")
                .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            AdaptiveStack(horizontalAlignment: .center, spacing: DS.Spacing.md) {
                Button("Terms of Use") { legal = .terms }
                    .accessibilityIdentifier("paywall.terms.link")
                Button("Privacy Policy") { legal = .privacy }
                    .accessibilityIdentifier("paywall.privacy.link")
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
        if case .failed(let message) = model.plans {
            // Prices couldn't load: say why here, where the button is, instead of showing a dead button.
            VStack(spacing: DS.Spacing.xs) {
                Text(message)
                    .font(DS.Typography.footnote.weight(.medium))
                    .foregroundStyle(DS.Colors.caution)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                AppButton("Try again", systemImage: "arrow.clockwise") { Task { await model.loadPlans() } }
                    .accessibilityIdentifier("paywall.retryPlans")
            }
        } else {
            purchaseControls(model)
        }
    }

    @ViewBuilder
    private func purchaseControls(_ model: PaywallModel) -> some View {
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
        guard let plan = model.selectedPlan else { return model.plans == .loading ? "Loading prices" : "Continue" }
        let action: String
        if case .failed = model.purchase {
            action = "Try again"
        } else if plan.isLifetime {
            action = "Buy once"
        } else if plan.introductoryOffer != nil {
            action = "Start free trial"
        } else {
            action = "Subscribe"
        }
        return "\(action) · \(plan.shortPrice)"
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
                Text(justPurchased ? "Gromax Pro is active" : "You have Gromax Pro")
                    .font(DS.Typography.title)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .accessibilityIdentifier("paywall.active")
                Text(entitlements.statusDescription())
                    .font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                PremiumFeatureRow(symbol: "figure.mind.and.body", title: "Every routine and the posture check", detail: "On the Plan tab.")
                PremiumFeatureRow(symbol: "doc.richtext", title: "Doctor-ready report", detail: "Profile › Reports, or from Growth.")
                PremiumFeatureRow(symbol: "chart.line.uptrend.xyaxis", title: "Advanced growth analysis", detail: "On the Growth tab.")
                PremiumFeatureRow(symbol: "person.2", title: "Family profiles", detail: "Add a child from the profile switcher.")
                PremiumFeatureRow(symbol: "sparkles", title: "Unlimited \(BrandConfig.current.assistantName)", detail: "From Home, Growth or Profile.")
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

#endif
