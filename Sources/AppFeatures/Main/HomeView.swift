#if os(iOS)
import SwiftUI
import GrowthCore
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
                            EstimateCardView(card: state.estimate).appearEffect(delay: 0.03)
                            GrowthPlaceholderCard(state: state).appearEffect(delay: 0.06)
                            QuickActionsRow(actions: state.quickActions, onAction: onAction).appearEffect(delay: 0.08)
                            HabitBaselineSection(habits: state.habits)
                            InsightCardView(insight: state.insight)
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
                        Badge(height.measuredWhen, tone: height.method == .estimate ? .caution : .neutral)
                    }
                }
                if let height = state.height {
                    Text(height.value)
                        .font(DS.Typography.metricLarge)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .contentTransition(.numericText())
                        .accessibilityLabel("Current height, \(height.accessibleValue), measured \(height.measuredWhen)")
                    if height.method == .estimate {
                        Text("Estimated. Measure to make this more reliable.")
                            .font(DS.Typography.footnote)
                            .foregroundStyle(DS.Colors.caution)
                    }
                }
                Divider().padding(.vertical, 2)
                if let change = state.change {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "arrow.up.right").foregroundStyle(DS.Colors.accent).accessibilityHidden(true)
                        Text(change.value).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                        Text(change.since).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(change.accessibleValue)
                } else if let hint = state.changeHint {
                    Text(hint).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                }
            }
        }
    }
}

struct EstimateCardView: View {
    let card: DashboardState.EstimateCard

    var body: some View {
        AppCard {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: card.availability == .engineNotAvailable ? "hourglass" : "scope")
                    .font(.title3)
                    .foregroundStyle(DS.Colors.accent)
                    .frame(width: 40, height: 40)
                    .background(DS.Colors.accentSoft, in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(card.title).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                        if card.availability == .engineNotAvailable { Badge("Coming soon", tone: .accent) }
                    }
                    Text(card.message)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct GrowthPlaceholderCard: View {
    let state: DashboardState

    var body: some View {
        MetricCard(label: "Growth percentile", value: nil, caption: state.percentileMessage, systemImage: "chart.bar.xaxis", placeholder: "Not available yet")
    }
}

struct QuickActionsRow: View {
    let actions: [DashboardState.QuickAction]
    let onAction: (DashboardState.QuickAction) -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
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
            Text("Daily check-ins arrive in a coming update. These are your starting points.")
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
    let insight: DashboardState.Insight

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: insight.symbol)
                .font(.title3)
                .foregroundStyle(DS.Colors.warm)
                .frame(width: 40, height: 40)
                .background(DS.Colors.warmSoft, in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                Text(insight.body).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsSurface()
        .accessibilityElement(children: .combine)
    }
}
#endif
