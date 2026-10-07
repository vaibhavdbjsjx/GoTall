#if os(iOS)
import SwiftUI
import Charts
import GrowthCore
import GrowthEngine
import DesignSystem

/// Premium analysis on the Growth tab. Free users see a labelled preview whose one line is computed from
/// their own measurements, plus what Premium adds. Nothing free is moved here.
struct AdvancedAnalysisSection: View {
    let profile: GrowthProfile
    @Environment(EntitlementStore.self) private var entitlements
    @State private var paywall: PaywallContext?

    var body: some View {
        let advanced = AdvancedGrowthAnalysis(profile: profile, now: Date(), calendar: .current)
        Group {
            if entitlements.access(.advancedAnalytics) == .available {
                PremiumAnalysisContent(advanced: advanced, unit: profile.unitPreference)
                    .transition(.opacity)
            } else {
                LockedFeaturePreview(
                    title: "Advanced growth analysis",
                    message: "Premium shows the full percentile history, growth speed between every pair of measurements, and how the estimate has changed as measurements were added.",
                    action: { paywall = .analysis }
                ) {
                    Text(advanced.summary)
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity)
                .accessibilityIdentifier("analysis.locked")
            }
        }
        .animation(Motion.standard, value: entitlements.isPremium)
        .paywallSheet($paywall)
    }
}

private struct PremiumAnalysisContent: View {
    let advanced: AdvancedGrowthAnalysis
    let unit: HeightUnit
    @State private var showsAll = false

    /// Whole years around the measured ages, so the line fills the chart instead of starting at age 0.
    private var ageDomain: ClosedRange<Double> {
        let ages = advanced.percentileHistory.map { $0.ageMonths / 12 }
        let lo = (ages.min() ?? 0).rounded(.down)
        let hi = max((ages.max() ?? 1).rounded(.up), lo + 1)
        return lo...hi
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            AdaptiveStack(horizontalAlignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                Text("Advanced growth analysis").font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0).hiddenAtAccessibilitySizes()
                PremiumBadge()
            }
            Text(advanced.summary).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if advanced.percentileHistory.count >= 2 {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Percentile over time").font(DS.Typography.subheadline.weight(.semibold)).foregroundStyle(DS.Colors.textSecondary)
                    Chart {
                        RuleMark(y: .value("50th", 50)).foregroundStyle(DS.Colors.separator).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        ForEach(advanced.percentileHistory) { row in
                            LineMark(x: .value("Age", row.ageMonths / 12), y: .value("Percentile", row.percentile))
                                .foregroundStyle(DS.Colors.accent)
                                .interpolationMethod(.monotone)
                            PointMark(x: .value("Age", row.ageMonths / 12), y: .value("Percentile", row.percentile))
                                .foregroundStyle(row.isEstimate ? DS.Colors.surface : DS.Colors.accent)
                                .symbolSize(36)
                        }
                    }
                    .chartYScale(domain: 0...100)
                    .chartXScale(domain: ageDomain)
                    .chartYAxis { AxisMarks(values: [3, 25, 50, 75, 97]) { value in
                        AxisGridLine().foregroundStyle(DS.Colors.separator.opacity(0.6))
                        AxisValueLabel { if let v = value.as(Int.self) { Text(PercentileFormatter.ordinalNumber(v)) } }
                    } }
                    .chartXAxisLabel("Age (years)")
                    .frame(height: 160)
                    .accessibilityLabel("Percentile over time")
                    .accessibilityValue(advanced.summary)
                }
            }

            if !advanced.velocityIntervals.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Growth speed between measurements").font(DS.Typography.subheadline.weight(.semibold)).foregroundStyle(DS.Colors.textSecondary)
                    ForEach(advanced.velocityIntervals.reversed().prefix(showsAll ? 20 : 3)) { interval in
                        AdaptiveStack(horizontalAlignment: .firstTextBaseline) {
                            Text("\(DisplayFormat.monthYear(interval.from, calendar: .current)) – \(DisplayFormat.monthYear(interval.to, calendar: .current))")
                                .font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textPrimary)
                            Spacer(minLength: 0).hiddenAtAccessibilitySizes()
                            Text("\(GrowthCopy.speed(interval.cmPerYear, unit: unit)) per year")
                                .font(DS.Typography.subheadline.monospacedDigit().weight(.semibold)).foregroundStyle(DS.Colors.textPrimary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            if advanced.estimateHistory.count >= 2 {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("How the estimate has changed").font(DS.Typography.subheadline.weight(.semibold)).foregroundStyle(DS.Colors.textSecondary)
                    ForEach(advanced.estimateHistory.reversed().prefix(showsAll ? 8 : 3)) { point in
                        AdaptiveStack(horizontalAlignment: .firstTextBaseline) {
                            Text(DisplayFormat.day(point.date, calendar: .current)).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textPrimary)
                            Spacer(minLength: 0).hiddenAtAccessibilitySizes()
                            Text(GrowthCopy.range(point.lowCm, point.highCm, unit: unit))
                                .font(DS.Typography.subheadline.monospacedDigit().weight(.semibold)).foregroundStyle(DS.Colors.textPrimary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    Text("Each range uses only the measurements available on that date. Estimates move as new data arrives; they aren't guarantees.")
                        .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if advanced.velocityIntervals.count > 3 || advanced.estimateHistory.count > 3 {
                Button(showsAll ? "Show less" : "Show all") { withAnimation(Motion.standard) { showsAll.toggle() } }
                    .font(DS.Typography.subheadline.weight(.semibold))
                    .tint(DS.Colors.accent)
            }
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsSurface()
        .accessibilityIdentifier("analysis.content")
    }
}
#endif
