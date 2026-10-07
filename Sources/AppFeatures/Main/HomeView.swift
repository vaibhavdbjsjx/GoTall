#if os(iOS)
import SwiftUI
import Charts
import GrowthCore
import GrowthEngine
import DesignSystem

/// Home answers three questions, in order: How am I doing? What's changed? What should I do next?
struct HomeView: View {
    let repository: AppRepository
    let onAction: (HomeAction) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if let profile = repository.activeProfile {
                    HomeContent(repository: repository, profile: profile, onAction: onAction)
                } else {
                    LoadingStateView()
                }
            }
            .dsPageBackground()
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

enum HomeAction {
    case measure, growth, habits, explanation, editFamily, switchProfile, report
}

private struct HomeContent: View {
    let repository: AppRepository
    let profile: GrowthProfile
    let onAction: (HomeAction) -> Void

    var body: some View {
        let now = Date()
        let analysis = GrowthAnalyzer(now: now, calendar: .current).analyze(profile)
        let state = DashboardBuilder(now: now, calendar: .current).build(for: profile, analysis: analysis)
        let status = GrowthStatus.from(analysis)
        let next = NextActionEngine.next(profile: profile, analysis: analysis, now: now, calendar: .current)
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                HomeHeader(state: state, repository: repository, onSwitch: { onAction(.switchProfile) })
                HomeHero(state: state, analysis: analysis, status: status)
                    .appearEffect()
                if case .range = state.estimate {
                    HomeEstimateCard(card: state.estimate, onTap: { onAction(.explanation) })
                        .appearEffect(delay: 0.04)
                }
                TrajectoryPreview(analysis: analysis, unit: profile.unitPreference, onTap: { onAction(.growth) })
                    .appearEffect(delay: 0.06)
                TodayCard(repository: repository, profile: profile, analysis: analysis, onOpenHabits: { onAction(.habits) })
                    .id("today")
                InsightCardView(insight: state.insight)
                    .id("insight")
                // Today's check-in is already one tap away in the Today card; don't repeat it as a next step.
                if next.kind != .checkIn {
                NextActionCard(action: next) { kind in
                    switch kind {
                    case .measureNow: onAction(.measure)
                    case .checkIn: onAction(.habits)
                    case .addParentHeights: onAction(.editFamily)
                    case .reviewGrowth, .measureLater: onAction(.growth)
                    }
                }
                }
                PremiumMomentCard(profile: profile, analysis: analysis, onOpen: { onAction(.report) })
                    .id("premium")
                if case .message(let title, let body) = state.estimate {
                    QuietNote(title: title, message: body, symbol: "scope")
                }
                if state.hasSafetyNote {
                    QuietNote(title: "About growth concerns", message: GrowthCopy.concernBody, symbol: "stethoscope")
                }
            }
            .padding(.horizontal, DS.Spacing.page)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .onAppear {
            #if DEBUG
            if let target = UserDefaults.standard.string(forKey: "homeScrollTo") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { proxy.scrollTo(target, anchor: .top) }
            }
            #endif
        }
        }
        .animation(Motion.standard, value: profile.id)
    }
}

private struct HomeHeader: View {
    let state: DashboardState
    let repository: AppRepository
    let onSwitch: () -> Void

    var body: some View {
        AdaptiveStack(horizontalAlignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(state.greeting)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(DS.Colors.textSecondary)
                Text(state.title)
                    .font(DS.Typography.display)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .contentTransition(.opacity)
            }
            Spacer(minLength: 0)
            ProfileSwitcherButton(repository: repository, action: onSwitch)
        }
        .padding(.top, DS.Spacing.md)
    }
}

/// The dominant growth state: height, percentile position on the door-frame ruler, and a data-justified status.
private struct HomeHero: View {
    let state: DashboardState
    let analysis: GrowthAnalysis
    let status: GrowthStatus
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 44

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label(status.title, systemImage: status.symbol)
                    .font(DS.Typography.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(DS.Colors.accent)
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, 5)
                    .background(DS.Colors.accentSoft, in: Capsule())
                if let height = state.height {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Height today").font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                        Text(height.value)
                            .font(.system(size: heroSize, weight: .semibold, design: .rounded).monospacedDigit())
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .foregroundStyle(DS.Colors.textPrimary)
                            .contentTransition(.numericText())
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Height, \(height.accessibleValue), measured \(height.measuredWhen)")
                }
                if let p = state.percentile {
                    Text(p.phrase.prefix(1).uppercased() + p.phrase.dropFirst())
                        .font(DS.Typography.headline)
                        .foregroundStyle(DS.Colors.textPrimary)
                } else if let reason = state.percentileUnavailableReason {
                    Text(reason).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    if let change = state.change {
                        Label {
                            Text("\(change.value) \(change.since)")
                        } icon: {
                            Image(systemName: change.direction > 0 ? "arrow.up.right" : (change.direction < 0 ? "arrow.down.right" : "arrow.right"))
                        }
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .accessibilityLabel(change.accessibleValue)
                    }
                    if let height = state.height {
                        Text(height.isEstimate ? "Estimated \(height.measuredWhen.lowercased())" : "Measured \(height.measuredWhen.lowercased())")
                            .font(DS.Typography.footnote)
                            .foregroundStyle(height.isEstimate ? DS.Colors.caution : DS.Colors.textTertiary)
                    }
                }
            }
            Spacer(minLength: 0)
            if let p = analysis.currentPercentile {
                DoorFrameRuler(z: p.z, markerLabel: PercentileFormatter.ordinal(p.percentile))
                    .frame(height: 176)
                    .hiddenAtAccessibilitySizes()
            }
        }
        .padding(DS.Spacing.lg)
        .heroSurface()
    }
}

struct HomeEstimateCard: View {
    let card: DashboardState.EstimateCard
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                if case .range(let value, let accessible, let uncertainty, let caption) = card {
                    AdaptiveStack(spacing: DS.Spacing.xs) {
                        Text(GrowthCopy.estimateTitle).font(DS.Typography.subheadline.weight(.semibold)).foregroundStyle(DS.Colors.textSecondary)
                        Spacer(minLength: DS.Spacing.xs).hiddenAtAccessibilitySizes()
                        Badge(GrowthCopy.uncertaintyLabel(uncertainty))
                    }
                    Text(value)
                        .font(DS.Typography.metric)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .accessibilityLabel("Estimated adult height, \(accessible)")
                    HStack {
                        Text(caption).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                        Spacer(minLength: DS.Spacing.xs)
                        Text("Why?").font(DS.Typography.footnote.weight(.semibold)).foregroundStyle(DS.Colors.accent)
                    }
                }
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsSurface()
        }
        .buttonStyle(PressableStyle())
        .accessibilityHint("Explains the estimate")
    }
}

/// A small chart preview: the person's line over the 25th–75th band. Taps through to Growth.
private struct TrajectoryPreview: View {
    let analysis: GrowthAnalysis
    let unit: HeightUnit
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    Text("Growth chart").font(DS.Typography.subheadline.weight(.semibold)).foregroundStyle(DS.Colors.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(DS.Colors.textTertiary)
                }
                if analysis.series.chartablePoints.isEmpty {
                    Text("Your measurements are kept in your history, even outside the chart's age range.")
                        .font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                } else {
                    let model = GrowthChartModel(series: analysis.series, sex: analysis.sex, unit: unit,
                                                 ageNowYears: (analysis.age?.exactMonths ?? 0) / 12, window: .focus)
                    Chart {
                        ForEach(model.innerBand) { p in
                            AreaMark(x: .value("Age", p.ageYears), yStart: .value("Low", p.low), yEnd: .value("High", p.high), series: .value("Band", "inner"))
                                .foregroundStyle(DS.Colors.accent.opacity(0.10))
                                .interpolationMethod(.monotone)
                        }
                        ForEach(model.points) { point in
                            LineMark(x: .value("Age", point.ageMonths / 12), y: .value("Height", model.display(point.heightCm)), series: .value("Line", "you"))
                                .foregroundStyle(DS.Colors.accent)
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .interpolationMethod(.monotone)
                        }
                        if let last = model.points.last {
                            PointMark(x: .value("Age", last.ageMonths / 12), y: .value("Height", model.display(last.heightCm)))
                                .foregroundStyle(DS.Colors.accent)
                                .symbolSize(60)
                        }
                    }
                    .chartXScale(domain: model.xDomain)
                    .chartYScale(domain: model.yDomain)
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 96)
                    .accessibilityHidden(true)
                    Text(model.points.count < 2 ? "Your line appears after your next measurement." : "\(model.points.count) measurements on the CDC chart")
                        .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                }
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsSurface()
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Growth chart, \(analysis.series.chartablePoints.count) measurements")
        .accessibilityHint("Opens Growth")
    }
}

/// Today's small actions: habit check-ins (inline) and the measurement interval when relevant.
private struct TodayCard: View {
    let repository: AppRepository
    let profile: GrowthProfile
    let analysis: GrowthAnalysis
    let onOpenHabits: () -> Void

    var body: some View {
        let engine = HabitEngine(today: Date(), calendar: .current)
        let habits = HabitEngine.activeHabits(for: profile)
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionHeader("Today", actionTitle: "Habits", action: onOpenHabits)
            AppCard(padding: 0) {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(engine.encouragement(in: profile))
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(DS.Colors.textSecondary)
                            .contentTransition(.opacity)
                        WeekDots(days: weekDays(engine: engine))
                    }
                    .padding(DS.Spacing.md)
                    Divider()
                    ForEach(Array(habits.enumerated()), id: \.element) { index, kind in
                        CheckInRow(title: kind.title, subtitle: kind.prompt, symbol: kind.symbol,
                                   isDone: engine.isCompleted(kind, on: Date(), in: profile)) {
                            withAnimation(Motion.standard) {
                                repository.toggleHabit(kind, on: Date(), for: profile.id, today: Date(), calendar: .current)
                            }
                        }
                        if index < habits.count - 1 { Divider().padding(.leading, 72) }
                    }
                    if let row = measurementRow() {
                        Divider()
                        row.padding(DS.Spacing.md)
                    }
                }
            }
        }
    }

    private func weekDays(engine: HabitEngine) -> [WeekDots.Day] {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")
        return engine.recentDays(7, in: profile).map {
            WeekDots.Day(id: $0.date, letter: formatter.string(from: $0.date), fraction: $0.fraction, isToday: $0.isToday)
        }
    }

    private func measurementRow() -> AnyView? {
        guard let next = analysis.nextMeasurement, let latest = analysis.latest,
              let band = analysis.age?.band, let months = GrowthAnalyzer.recommendedIntervalMonths(for: band) else { return nil }
        let total = Double(months) * 30.4375
        let elapsed = Double(AgeMath.days(from: latest.date, to: Date(), calendar: .current))
        let remaining = max(0, Int((total - elapsed).rounded()))
        return AnyView(HStack(spacing: DS.Spacing.md) {
            IntervalRing(fraction: elapsed / total, label: next.isDue ? "Due" : "\(remaining)d")
                .hiddenAtAccessibilitySizes()
            VStack(alignment: .leading, spacing: 2) {
                Text(next.isDue ? "Measurement due" : "Next measurement").font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                Text(next.isDue ? "A new measurement keeps the chart current." : "In about \(remaining) days. Every \(months) months is plenty.")
                    .font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine))
    }
}

private struct NextActionCard: View {
    let action: NextAction
    let perform: (NextAction.Kind) -> Void

    var body: some View {
        if action.isActionable {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Next step").font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                Text(action.detail).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                AppButton(action.title, systemImage: action.symbol) { perform(action.kind) }
            }
            .padding(DS.Spacing.md)
            .dsSurface()
        } else {
            QuietNote(title: action.title, message: action.detail, symbol: action.symbol)
        }
    }
}

/// Low-emphasis information row (no card chrome), for context that shouldn't compete with the hero.
struct QuietNote: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: symbol).foregroundStyle(DS.Colors.textTertiary).frame(width: 24).accessibilityHidden(true)
                .hiddenAtAccessibilitySizes()
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(DS.Typography.subheadline.weight(.semibold)).foregroundStyle(DS.Colors.textPrimary)
                Text(message).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

struct InsightCardView: View {
    let insight: GrowthInsight

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Label("Insight", systemImage: "sparkle")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.warm)
            Text(insight.title).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
            Text(insight.body).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.warmSoft.opacity(0.55), in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct HabitBaselineSection: View {
    let habits: [DashboardState.HabitBaseline]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionHeader("Starting points")
            AppCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                        AdaptiveStack {
                            Text(habit.title).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
                            Spacer(minLength: 0)
                            Text(habit.value ?? "Not set")
                                .font(DS.Typography.subheadline)
                                .foregroundStyle(habit.value == nil ? DS.Colors.textTertiary : DS.Colors.textSecondary)
                        }
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .frame(minHeight: 48)
                        .accessibilityElement(children: .combine)
                        if index < habits.count - 1 { Divider().padding(.leading, DS.Spacing.md) }
                    }
                }
            }
        }
    }
}

/// The one place Home mentions Premium. Free: a dismissible suggestion, shown only once a growth trend exists
/// (real value first) and snoozed for 60 days when dismissed. Premium: a shortcut to the report.
private struct PremiumMomentCard: View {
    let profile: GrowthProfile
    let analysis: GrowthAnalysis
    let onOpen: () -> Void
    @Environment(EntitlementStore.self) private var entitlements
    @AppStorage("premiumOfferDismissedAt") private var dismissedAt: Double = 0

    var body: some View {
        if entitlements.isPremium {
            card(eyebrow: "Doctor-ready report",
                 title: "Ready for the next check-up",
                 detail: "\(profile.measurements.count) measurement\(profile.measurements.count == 1 ? "" : "s"), the growth chart, percentile history and methods, as a PDF made on this iPhone.",
                 button: "Open report", showsDismiss: false)
                .accessibilityIdentifier("home.report")
        } else if PremiumOfferPolicy.shouldSuggest(analysis: analysis, isPremium: false,
                                                   dismissedAt: dismissedAt > 0 ? Date(timeIntervalSince1970: dismissedAt) : nil,
                                                   now: Date(), calendar: .current) {
            card(eyebrow: "Premium",
                 title: "A clear report for the doctor",
                 detail: "\(profile.subject == .child ? (profile.nickname ?? "This") + "'s" : "Your") growth history can become a PDF with the chart, every measurement and the methods behind them.",
                 button: "See what's included", showsDismiss: true)
                .accessibilityIdentifier("home.premiumOffer")
        }
    }

    private func card(eyebrow: String, title: String, detail: String, button: String, showsDismiss: Bool) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(eyebrow.uppercased()).font(DS.Typography.eyebrow).foregroundStyle(DS.Colors.accent)
                    Text(title).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                    Text(detail).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                ReportPreview(compact: true)
                    .scaleEffect(0.8)
                    .frame(width: 100, height: 110)
                    .hiddenAtAccessibilitySizes()
            }
            AdaptiveStack(horizontalAlignment: .center, spacing: DS.Spacing.xs) {
                AppButton(button, kind: .secondary, fullWidth: !showsDismiss, action: onOpen)
                if showsDismiss {
                    AppButton("Not now", kind: .tertiary, fullWidth: false) {
                        withAnimation(Motion.standard) { dismissedAt = Date().timeIntervalSince1970 }
                    }
                    .accessibilityIdentifier("home.premiumOffer.dismiss")
                }
            }
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsSurface()
    }
}
#endif
