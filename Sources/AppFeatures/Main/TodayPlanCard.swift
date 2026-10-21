#if os(iOS)
import SwiftUI
import GrowthCore
import DesignSystem

/// Home's "Your plan today": a ring for how much of today's short plan is done, then one row per item.
/// The routine starts right here; everything else opens the Plan tab where its tool lives.
struct TodayPlanCard: View {
    let repository: AppRepository
    let profile: GrowthProfile
    let analysis: GrowthAnalysis
    let onOpenPlan: () -> Void
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(AppNavigator.self) private var navigator
    @State private var playing: Routine?

    var body: some View {
        let now = Date()
        let isPro = entitlements.isPremium
        let plan = TodayPlan.make(profile: profile, analysis: analysis, isPremium: isPro, today: now, calendar: .current)
        let progression = Progression(profile: profile, today: now, calendar: .current)
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionHeader("Your plan today", actionTitle: "Plan", action: onOpenPlan)
            AppCard(padding: 0) {
                VStack(spacing: 0) {
                    HStack(spacing: DS.Spacing.md) {
                        ProgressRing(progress: plan.fraction, lineWidth: 7) {
                            Text("\(plan.doneCount)/\(plan.items.count)")
                                .font(DS.Typography.metricSmall)
                                .foregroundStyle(DS.Colors.textPrimary)
                                .contentTransition(.numericText())
                        }
                        .frame(width: 64, height: 64)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(headline(plan)).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                            LevelChip(level: progression.level.number, name: progression.level.name, progress: progression.progressToNext)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(DS.Spacing.md)
                    .accessibilityElement(children: .combine)
                    ForEach(plan.items) { item in
                        Divider().padding(.leading, DS.Spacing.md)
                        PlanItemRow(item: item, showsProBadge: item.isPro && !isPro) { open(item, isPro: isPro) }
                    }
                }
            }
        }
        .fullScreenCover(item: $playing) { routine in
            RoutinePlayerView(routine: routine, repository: repository, profileID: profile.id)
        }
    }

    private func headline(_ plan: TodayPlan) -> String {
        if plan.items.isEmpty { return "Nothing planned today" }
        if plan.doneCount == plan.items.count { return "All done. Nice work." }
        if plan.doneCount == 0 { return "\(plan.items.count) small things for today" }
        return "\(plan.items.count - plan.doneCount) left for today"
    }

    private func open(_ item: TodayPlan.Item, isPro: Bool) {
        if item.isPro && !isPro {
            switch item.kind {
            case .postureCheck: navigator.showPaywall(.posture)
            default: navigator.showPaywall(.routines)
            }
            return
        }
        switch item.kind {
        case .routine(let id):
            if let routine = RoutineLibrary.all.first(where: { $0.id == id }) { playing = routine }
        default:
            onOpenPlan()
        }
    }
}

private struct PlanItemRow: View {
    let item: TodayPlan.Item
    let showsProBadge: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    Circle().fill(item.isDone ? DS.Colors.accent : DS.Colors.accentSoft)
                    Image(systemName: item.isDone ? "checkmark" : item.symbol)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(item.isDone ? DS.Colors.onAccent : DS.Colors.accent)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title).font(DS.Typography.subheadline.weight(.semibold))
                        .foregroundStyle(item.isDone ? DS.Colors.textSecondary : DS.Colors.textPrimary)
                        .strikethrough(item.isDone, color: DS.Colors.textTertiary)
                    Text(item.detail).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                }
                Spacer(minLength: 0)
                if showsProBadge {
                    PremiumBadge()
                } else {
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(DS.Colors.textTertiary)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(item.isDone ? "Done" : "Not done")
        .accessibilityIdentifier("home.plan.\(item.id)")
    }
}
#endif
