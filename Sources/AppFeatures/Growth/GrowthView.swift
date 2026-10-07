#if os(iOS)
import SwiftUI
import GrowthCore
import GrowthEngine
import DesignSystem

/// The Growth tab: where the person is now, how they've been growing, and what to track next.
/// Order follows the questions a parent or teen asks; details are behind sheets and disclosures.
struct GrowthView: View {
    let repository: AppRepository
    @State private var window: ChartWindow = .focus
    @State private var selectedPoint: SeriesPoint?
    @State private var editor: MeasurementEditorRoute?
    @State private var showsExplanation = false
    @State private var showsGuide = false
    @State private var showsHistory = false

    var body: some View {
        NavigationStack {
            Group {
                if let profile = repository.activeProfile {
                    content(profile: profile, analysis: GrowthAnalyzer(now: Date(), calendar: .current).analyze(profile))
                } else {
                    LoadingStateView()
                }
            }
            .dsPageBackground()
            .navigationTitle("Growth")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { ProfileSwitcher(repository: repository) }
                ToolbarItem(placement: .primaryAction) {
                    Button { editor = .add } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add measurement")
                }
            }
            .sheet(item: $editor) { route in
                if let profile = repository.activeProfile {
                    MeasurementEditorSheet(repository: repository, profile: profile, route: route)
                }
            }
            .sheet(isPresented: $showsGuide) { MeasurementGuideView() }
            .navigationDestination(isPresented: $showsHistory) {
                MeasurementHistoryView(repository: repository)
            }
            .onChange(of: repository.activeProfile?.id) { _, _ in selectedPoint = nil }
        }
    }

    @ViewBuilder
    private func content(profile: GrowthProfile, analysis: GrowthAnalysis) -> some View {
        let unit = profile.unitPreference
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                CurrentStatusCard(analysis: analysis, unit: unit, onMeasure: { editor = .add }, onGuide: { showsGuide = true })
                    .appearEffect()

                chartSection(profile: profile, analysis: analysis)
                    .appearEffect(delay: 0.03)

                VelocityCard(velocity: analysis.velocity, unit: unit)
                    .appearEffect(delay: 0.05)
                    .id("velocity")

                AdultHeightCard(outcome: analysis.adultHeight, unit: unit, isChild: profile.subject == .child,
                                onExplain: { showsExplanation = true })
                    .appearEffect(delay: 0.07)
                    .id("estimate")

                if analysis.family != .notApplicable {
                    FamilyHeightCard(status: analysis.family, unit: unit)
                        .id("family")
                }

                if profile.intent == .concerned || !analysis.signposts.isEmpty {
                    SafetyCard(signposts: analysis.signposts)
                }

                InsightsSection(insights: Array(analysis.insights.prefix(3)))
                    .id("insights")

                historySection(profile: profile)
                    .id("history")

                GuideLinkCard { showsGuide = true }

                Text("\(analysis.referenceName). For information only; this app doesn't diagnose. Talk to a doctor about any concerns.")
                    .font(DS.Typography.footnote)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .padding(.top, DS.Spacing.xs)
            }
            .padding(.horizontal, DS.Spacing.page)
            .padding(.vertical, DS.Spacing.md)
        }
        .onAppear {
            #if DEBUG
            // Screenshot harness: `-growthScrollTo estimate` and `-openExplanation YES` launch arguments.
            if let target = UserDefaults.standard.string(forKey: "growthScrollTo") { proxy.scrollTo(target, anchor: .top) }
            if UserDefaults.standard.bool(forKey: "openExplanation") { showsExplanation = true }
            #endif
        }
        }
        .sheet(isPresented: $showsExplanation) {
            if case .scenario(let scenario) = analysis.adultHeight {
                EstimateExplanationSheet(analysis: analysis, scenario: scenario)
            }
        }
    }

    @ViewBuilder
    private func chartSection(profile: GrowthProfile, analysis: GrowthAnalysis) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    Text("Growth chart").font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary).accessibilityAddTraits(.isHeader)
                    Spacer()
                    if !analysis.series.chartablePoints.isEmpty {
                        SegmentedChoice("Chart range", options: ChartWindow.allCases, selection: $window) { $0.title }
                            .frame(maxWidth: 200)
                    }
                }
                if analysis.series.chartablePoints.isEmpty {
                    EmptyStateView(systemImage: "chart.xyaxis.line", title: "Charts cover ages 2–20",
                                   message: "Measurements outside that age range are kept in the history below.")
                } else {
                    let model = GrowthChartModel(series: analysis.series, sex: analysis.sex, unit: profile.unitPreference,
                                                 ageNowYears: (analysis.age?.exactMonths ?? 0) / 12, window: window)
                    GrowthChartView(model: model, selected: $selectedPoint)
                    if let point = selectedPoint ?? analysis.series.chartablePoints.last {
                        SelectedPointDetail(point: point, unit: profile.unitPreference)
                    }
                    ChartLegend()
                    if analysis.series.chartablePoints.count == 1 {
                        InfoBanner("This is where you sit on the chart today. Your own growth line appears after your next measurement.")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func historySection(profile: GrowthProfile) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionHeader("Measurements", actionTitle: profile.measurements.count > 3 ? "See all" : nil) { showsHistory = true }
            AppCard(padding: DS.Spacing.md) {
                VStack(spacing: 0) {
                    let recent = Array(profile.sortedMeasurements.reversed().prefix(3))
                    ForEach(Array(recent.enumerated()), id: \.element.id) { index, m in
                        Button { editor = .edit(m) } label: {
                            MeasurementRow(value: HeightFormatter.string(centimeters: m.heightCm, unit: profile.unitPreference),
                                           accessibleValue: HeightFormatter.accessibleString(centimeters: m.heightCm, unit: profile.unitPreference),
                                           date: DisplayFormat.day(m.date, calendar: .current),
                                           detail: m.method.title)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Edit this measurement")
                        if index < recent.count - 1 { Divider() }
                    }
                }
            }
            Button { showsHistory = true } label: {
                Label("Manage all measurements", systemImage: "list.bullet")
                    .font(DS.Typography.subheadline.weight(.semibold))
                    .frame(minHeight: DS.minimumTapTarget)
            }
            .foregroundStyle(DS.Colors.accent)
        }
    }
}

// MARK: - Cards

struct CurrentStatusCard: View {
    let analysis: GrowthAnalysis
    let unit: HeightUnit
    let onMeasure: () -> Void
    let onGuide: () -> Void

    var body: some View {
        AppCard(padding: DS.Spacing.lg) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                AdaptiveStack(horizontalAlignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current height").font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                        if let latest = analysis.latest {
                            Text(HeightFormatter.string(centimeters: latest.heightCm, unit: unit))
                                .font(DS.Typography.metricLarge)
                                .foregroundStyle(DS.Colors.textPrimary)
                                .contentTransition(.numericText())
                            Text(DisplayFormat.relative(latest.date, to: Date(), calendar: .current))
                                .font(DS.Typography.footnote)
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                    if let p = analysis.currentPercentile {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Percentile").font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                            Text(PercentileFormatter.ordinal(p.percentile))
                                .font(DS.Typography.metric)
                                .foregroundStyle(DS.Colors.accent)
                                .contentTransition(.numericText())
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                if let p = analysis.currentPercentile, (1...99).contains(Int(p.percentile.rounded())) {
                    Text("Out of 100 people of the same age and sex on the CDC chart, about \(Int(p.percentile.rounded())) would be shorter.")
                        .font(DS.Typography.footnote)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if analysis.latestIsEstimate {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        InfoBanner(GrowthCopy.estimatedNotice, tone: .caution)
                        HStack {
                            AppButton("Measure", systemImage: "ruler", kind: .secondary, fullWidth: false, action: onMeasure)
                            AppButton("How to measure", kind: .tertiary, fullWidth: false, action: onGuide)
                        }
                    }
                }
            }
        }
    }
}

struct VelocityCard: View {
    let velocity: VelocityAvailability
    let unit: HeightUnit

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Label(GrowthCopy.velocityTitle, systemImage: "speedometer")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.textPrimary)
                switch velocity {
                case .available(let v):
                    if v.direction == .increasing {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(GrowthCopy.speed(v.cmPerYear, unit: unit))
                                .font(DS.Typography.metric)
                                .foregroundStyle(DS.Colors.textPrimary)
                            Text("per year").font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                        }
                        .accessibilityElement(children: .combine)
                    } else {
                        Text(v.direction == .littleChange ? "Little change" : "Lower than before")
                            .font(DS.Typography.metricSmall)
                            .foregroundStyle(DS.Colors.textPrimary)
                    }
                    Text(GrowthCopy.velocitySentence(v, unit: unit))
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(DS.Colors.textSecondary)
                    if v.involvesEstimate {
                        Text("Includes an estimated height, so treat this as rough.")
                            .font(DS.Typography.footnote)
                            .foregroundStyle(DS.Colors.caution)
                    }
                case .needsMoreTime(let date):
                    Text("Not enough time between measurements yet.")
                        .font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
                    Text("Growth speed needs at least 6 months between measurements. Measure again after \(DisplayFormat.day(date, calendar: .current)).")
                        .font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                case .needsMoreMeasurements:
                    Text("Not enough measurements yet.")
                        .font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
                    Text(GrowthCopy.velocityNeedsMore)
                        .font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                }
            }
        }
    }
}

struct AdultHeightCard: View {
    let outcome: AdultHeightOutcome
    let unit: HeightUnit
    let isChild: Bool
    let onExplain: () -> Void

    var body: some View {
        AppCard(padding: DS.Spacing.lg) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                if case .scenario(let s) = outcome {
                    AdaptiveStack {
                        Text(GrowthCopy.estimateTitle).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                        Spacer(minLength: 0)
                        Badge(GrowthCopy.uncertaintyLabel(s.uncertainty), tone: s.uncertainty == .narrower ? .accent : .neutral)
                    }
                    Text(GrowthCopy.range(s.lowCm, s.highCm, unit: unit))
                        .font(DS.Typography.metricLarge)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .accessibilityLabel("Estimated adult height, \(GrowthCopy.accessibleRange(s.lowCm, s.highCm, unit: unit))")
                    RangeBar(scenario: s)
                    Text(GrowthCopy.estimateDisclaimer)
                        .font(DS.Typography.subheadline.weight(.semibold))
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text("\(GrowthCopy.estimateBasis) \(GrowthCopy.estimateLimit)")
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    AppButton("Why this estimate?", systemImage: "questionmark.circle", kind: .secondary, action: onExplain)
                } else if let message = GrowthCopy.outcomeMessage(outcome, isChild: isChild) {
                    Label(message.title, systemImage: "scope")
                        .font(DS.Typography.headline)
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text(message.body)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// A horizontal bar showing the scenario channel's percentile lines, so the range reads as a band, not a point.
struct RangeBar: View {
    let scenario: AdultHeightScenario

    var body: some View {
        GeometryReader { proxy in
            let lines = MajorPercentile.allCases
            let width = proxy.size.width
            let lowerIndex = CGFloat(lines.firstIndex(of: scenario.lowerLine) ?? 0)
            let upperIndex = CGFloat(lines.firstIndex(of: scenario.upperLine) ?? 0)
            let step = width / CGFloat(lines.count - 1)
            ZStack(alignment: .leading) {
                Capsule().fill(DS.Colors.surfaceSecondary).frame(height: 8)
                Capsule().fill(DS.Colors.accent.opacity(0.85))
                    .frame(width: max(8, (upperIndex - lowerIndex) * step), height: 8)
                    .offset(x: lowerIndex * step)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 12)
        .overlay(alignment: .bottom) {
            HStack {
                ForEach(MajorPercentile.allCases, id: \.self) { line in
                    Text(PercentileFormatter.ordinal(Double(line.rawValue)))
                    if line != .p97 { Spacer(minLength: 0) }
                }
            }
            .font(.caption2)
            .foregroundStyle(DS.Colors.textTertiary)
            .offset(y: 16)
        }
        .padding(.bottom, 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Range covers the \(PercentileFormatter.ordinal(Double(scenario.lowerLine.rawValue))) to \(PercentileFormatter.ordinal(Double(scenario.upperLine.rawValue))) percentile lines")
    }
}

struct FamilyHeightCard: View {
    let status: FamilyHeightStatus
    let unit: HeightUnit
    @State private var showsDetails = false

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label(GrowthCopy.familyTitle, systemImage: "person.2")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.textPrimary)
                switch status {
                case .available(let range):
                    Text(GrowthCopy.range(range.lowCm, range.highCm, unit: unit))
                        .font(DS.Typography.metric)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .accessibilityLabel("Family-height range, \(GrowthCopy.accessibleRange(range.lowCm, range.highCm, unit: unit))")
                    Text("Midpoint \(HeightFormatter.string(centimeters: range.targetCm, unit: unit))\(range.targetAdultPercentile.map { ", around the \(PercentileFormatter.phrase($0.percentile)) of adult heights" } ?? "").")
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(DS.Colors.textSecondary)
                    Badge("Context, not a prediction", tone: .neutral)
                    if range.usesEstimatedParentHeight {
                        Text("Uses an estimated parent height, which tends to be a little high.")
                            .font(DS.Typography.footnote).foregroundStyle(DS.Colors.caution)
                    }
                    DisclosureGroup(isExpanded: $showsDetails) {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text(GrowthCopy.familyExplanation)
                            Text(GrowthCopy.familyFormula).foregroundStyle(DS.Colors.textSecondary)
                            Text(GrowthCopy.familyLimitations).foregroundStyle(DS.Colors.textSecondary)
                        }
                        .font(DS.Typography.footnote)
                        .padding(.top, DS.Spacing.xs)
                    } label: {
                        Text("How this works").font(DS.Typography.subheadline.weight(.semibold)).foregroundStyle(DS.Colors.accent)
                    }
                    .tint(DS.Colors.accent)
                case .missingParentHeights:
                    Text(GrowthCopy.familyMissing)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(DS.Colors.textSecondary)
                case .notApplicable:
                    EmptyView()
                }
            }
        }
    }
}

struct SafetyCard: View {
    let signposts: [GrowthSignpost]

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label("About growth concerns", systemImage: "stethoscope")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.textPrimary)
                ForEach(Array(signposts.enumerated()), id: \.offset) { _, signpost in
                    InfoBanner(GrowthCopy.signpostText(signpost), tone: .caution)
                }
                Text(GrowthCopy.concernBody)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct InsightsSection: View {
    let insights: [GrowthInsight]

    var body: some View {
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                SectionHeader("Insights")
                ForEach(insights) { InsightCardView(insight: $0) }
            }
        }
    }
}

struct GuideLinkCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "ruler")
                    .font(.title3)
                    .foregroundStyle(DS.Colors.accent)
                    .frame(width: 40, height: 40)
                    .background(DS.Colors.accentSoft, in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("How to measure accurately").font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                    Text("Six steps for consistent results").font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(DS.Colors.textTertiary)
            }
            .padding(DS.Spacing.md)
            .dsSurface()
        }
        .buttonStyle(PressableStyle())
    }
}
#endif
