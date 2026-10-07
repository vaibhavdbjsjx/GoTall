#if os(iOS)
import SwiftUI
import GrowthCore
import GrowthEngine
import DesignSystem

/// "Why this estimate?": what affected the number, what's context only, and what did not affect it.
struct EstimateExplanationSheet: View {
    let analysis: GrowthAnalysis
    let scenario: AdultHeightScenario
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let explanation = GrowthCopy.explanation(for: analysis, scenario: scenario, calendar: .current)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    AppCard(padding: DS.Spacing.lg) {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Text(GrowthCopy.range(scenario.lowCm, scenario.highCm, unit: analysis.unit))
                                .font(DS.Typography.metricLarge)
                                .foregroundStyle(DS.Colors.textPrimary)
                            Text(GrowthCopy.scenarioSentence(scenario))
                                .font(DS.Typography.body)
                                .foregroundStyle(DS.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    section(title: "What affected the estimate", items: explanation.used, tone: .accent)
                    if !explanation.contextOnly.isEmpty {
                        section(title: "Shown alongside, not included", items: explanation.contextOnly, tone: .neutral)
                    }
                    section(title: "What did not affect it", items: explanation.notUsed, tone: .neutral)

                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        SectionHeader("How certain is it?")
                        AppCard {
                            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                                Badge(GrowthCopy.uncertaintyLabel(scenario.uncertainty), tone: .accent)
                                Text(GrowthCopy.uncertaintyExplanation(scenario.uncertainty))
                                    .font(DS.Typography.body)
                                    .foregroundStyle(DS.Colors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                ForEach(scenario.drivers, id: \.self) { driver in
                                    Label(GrowthCopy.driverText(driver), systemImage: "circle.fill")
                                        .labelStyle(BulletLabelStyle())
                                        .font(DS.Typography.subheadline)
                                        .foregroundStyle(DS.Colors.textSecondary)
                                }
                                Text("We don't show a percentage, because no validation study supports a precise accuracy figure for this method.")
                                    .font(DS.Typography.footnote)
                                    .foregroundStyle(DS.Colors.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        SectionHeader("The method")
                        Text(GrowthCopy.methodSummary)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(DS.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(GrowthCopy.estimateLimit)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                }
                .padding(DS.Spacing.page)
            }
            .dsPageBackground()
            .navigationTitle("Why this estimate?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDragIndicator(.visible)
    }

    private func section(title: String, items: [GrowthCopy.ExplanationItem], tone: Badge.Tone) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionHeader(title)
            AppCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        HStack(alignment: .top, spacing: DS.Spacing.sm) {
                            Image(systemName: item.symbol)
                                .foregroundStyle(tone == .accent ? DS.Colors.accent : DS.Colors.textTertiary)
                                .frame(width: 28)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(DS.Typography.subheadline.weight(.semibold)).foregroundStyle(DS.Colors.textPrimary)
                                Text(item.detail).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(DS.Spacing.md)
                        .accessibilityElement(children: .combine)
                        if index < items.count - 1 { Divider().padding(.leading, 52) }
                    }
                }
            }
        }
    }
}

struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
            configuration.icon.font(.system(size: 5)).foregroundStyle(DS.Colors.textTertiary)
            configuration.title
        }
    }
}
#endif
