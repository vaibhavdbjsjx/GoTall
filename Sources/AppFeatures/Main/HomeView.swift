#if os(iOS)
import SwiftUI
import GrowthCore
import GrowthEngine
import DesignSystem

struct HomeView: View {
    let repository: AppRepository
    let onAction: (DashboardState.QuickAction) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if let profile = repository.activeProfile {
                    let state = DashboardBuilder(now: Date(), calendar: .current).build(for: profile)
                    ScrollView {
                        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                            header(state)
                            HeightHeroCard(state: state).appearEffect()
                            HomeEstimateCard(card: state.estimate, onTap: { onAction(.viewGrowth) }).appearEffect(delay: 0.03)
                            AdaptiveStack(horizontalAlignment: .top, spacing: DS.Spacing.sm) {
                                MetricCard(label: "Growth speed", value: state.velocityValue, caption: state.velocityValue == nil ? "Needs two measurements 6+ months apart" : "Based on your last measurements", systemImage: "speedometer", placeholder: "Not yet")
                                if let family = state.family {
                                    MetricCard(label: "Family height", value: family.value, caption: family.caption, systemImage: "person.2", placeholder: "Not set")
                                }
                            }
                            .appearEffect(delay: 0.05)
                            QuickActionsRow(actions: state.quickActions, onAction: onAction).appearEffect(delay: 0.07)
                            if let next = state.nextMeasurement {
                                InfoBanner(next, title: "Next step", tone: state.nextMeasurement?.hasPrefix("A new") == true ? .caution : .info)
                            }
                            InsightCardView(insight: state.insight)
                            if state.hasSafetyNote {
                                InfoBanner(GrowthCopy.concernBody, title: "About growth concerns", tone: .info)
                            }
                            HabitBaselineSection(habits: state.habits)
                        }
                        .padding(.horizontal, DS.Spacing.page)
                        .padding(.bottom, DS.Spacing.xxl)
                    }
                } else {
                    LoadingStateView()
                }
            }
            .dsPageBackground()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func header(_ state: DashboardState) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(state.greeting)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(DS.Colors.textSecondary)
                Text(state.title)
                    .font(DS.Typography.display)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer()
            ProfileSwitcher(repository: repository)
        }
        .padding(.top, DS.Spacing.md)
    }
}

struct HeightHeroCard: View {
    let state: DashboardState

    var body: some View {
        AppCard(padding: DS.Spacing.lg) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    Text("Current height").font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                    Spacer()
                    if let height = state.height {
                        Badge(height.measuredWhen, tone: height.isEstimate ? .caution : .neutral)
                    }
                }
                AdaptiveStack(horizontalAlignment: .firstTextBaseline) {
                    if let height = state.height {
                        Text(height.value)
                            .font(DS.Typography.metricLarge)
                            .foregroundStyle(DS.Colors.textPrimary)
                            .contentTransition(.numericText())
                            .accessibilityLabel("Current height, \(height.accessibleValue), measured \(height.measuredWhen)")
                    }
                    Spacer(minLength: 0)
                    if let p = state.percentile {
                        Text(p.phrase)
                            .font(DS.Typography.headline)
                            .foregroundStyle(DS.Colors.accent)
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, 6)
                            .background(DS.Colors.accentSoft, in: Capsule())
                    }
                }
                if let height = state.height, height.isEstimate {
                    Text(GrowthCopy.estimatedNotice)
                        .font(DS.Typography.footnote)
                        .foregroundStyle(DS.Colors.caution)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Divider().padding(.vertical, 2)
                if let change = state.change {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: change.direction > 0 ? "arrow.up.right" : (change.direction < 0 ? "arrow.down.right" : "arrow.right"))
                            .foregroundStyle(DS.Colors.accent).accessibilityHidden(true)
                        Text(change.value).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                        Text(change.since).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(change.accessibleValue)
                } else if let hint = state.changeHint {
                    Text(hint).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                }
                if let reason = state.percentileUnavailableReason {
                    Text(reason).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textTertiary)
                }
            }
        }
    }
}

struct HomeEstimateCard: View {
    let card: DashboardState.EstimateCard
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: "scope")
                    .font(.title3)
                    .foregroundStyle(DS.Colors.accent)
                    .frame(width: 40, height: 40)
                    .background(DS.Colors.accentSoft, in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    .accessibilityHidden(true)
                    .hiddenAtAccessibilitySizes()
                VStack(alignment: .leading, spacing: 4) {
                    switch card {
                    case .range(let value, let accessible, let uncertainty, let caption):
                        Text(GrowthCopy.estimateTitle).font(DS.Typography.subheadline.weight(.semibold)).foregroundStyle(DS.Colors.textSecondary)
                        Badge(GrowthCopy.uncertaintyLabel(uncertainty))
                        Text(value).font(DS.Typography.metric).foregroundStyle(DS.Colors.textPrimary)
                            .accessibilityLabel("Estimated adult height, \(accessible)")
                        Text(caption).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                    case .message(let title, let body):
                        Text(title).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                        Text(body).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .multilineTextAlignment(.leading)
                Image(systemName: "chevron.right").foregroundStyle(DS.Colors.textTertiary).accessibilityHidden(true)
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsSurface()
        }
        .buttonStyle(PressableStyle())
        .accessibilityHint("Opens Growth")
    }
}

struct QuickActionsRow: View {
    let actions: [DashboardState.QuickAction]
    let onAction: (DashboardState.QuickAction) -> Void

    var body: some View {
        AdaptiveStack(spacing: DS.Spacing.sm) {
            ForEach(actions) { action in
                Button { onAction(action) } label: {
                    VStack(spacing: DS.Spacing.xs) {
                        Image(systemName: action.symbol)
                            .font(.title3)
                            .foregroundStyle(action == .measure ? DS.Colors.onAccent : DS.Colors.accent)
                            .frame(width: 44, height: 44)
                            .background(action == .measure ? DS.Colors.accent : DS.Colors.accentSoft, in: Circle())
                        Text(action.title)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 88)
                    .padding(.vertical, DS.Spacing.xs)
                    .dsSurface(radius: DS.Radius.md)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(action.title)
            }
        }
    }
}

struct HabitBaselineSection: View {
    let habits: [DashboardState.HabitBaseline]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionHeader("Daily habits")
            AppCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: symbol(habit.kind)).foregroundStyle(DS.Colors.accent).frame(width: 28).accessibilityHidden(true)
                            Text(habit.title).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
                            Spacer()
                            Text(habit.value ?? "Not set")
                                .font(DS.Typography.subheadline)
                                .foregroundStyle(habit.value == nil ? DS.Colors.textTertiary : DS.Colors.textSecondary)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding(.horizontal, DS.Spacing.md)
                        .frame(minHeight: 52)
                        .accessibilityElement(children: .combine)
                        if index < habits.count - 1 { Divider().padding(.leading, 52) }
                    }
                }
            }
            Text("Habits support healthy development. They don't change any height estimate. Daily check-ins arrive in a coming update.")
                .font(DS.Typography.footnote)
                .foregroundStyle(DS.Colors.textSecondary)
        }
    }

    private func symbol(_ kind: DashboardState.HabitKind) -> String {
        switch kind {
        case .sleep: return "moon"
        case .activity: return "figure.run"
        case .nutrition: return "fork.knife"
        }
    }
}

struct InsightCardView: View {
    let insight: GrowthInsight

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: insight.symbol)
                .font(.title3)
                .foregroundStyle(DS.Colors.warm)
                .frame(width: 40, height: 40)
                .background(DS.Colors.warmSoft, in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                .accessibilityHidden(true)
                .hiddenAtAccessibilitySizes()
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                Text(insight.body).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsSurface()
        .accessibilityElement(children: .combine)
    }
}
#endif
