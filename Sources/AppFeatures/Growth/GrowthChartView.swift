#if os(iOS)
import SwiftUI
import Charts
import Accessibility
import GrowthCore
import GrowthEngine
import DesignSystem

enum ChartWindow: String, CaseIterable, Identifiable {
    case focus, full
    var id: String { rawValue }
    var title: String { self == .focus ? "Your range" : "Ages 2–20" }
}

/// Precomputed chart data. Built by the parent so selection changes don't recompute curves.
struct GrowthChartModel {
    struct BandPoint: Identifiable {
        var ageYears: Double
        var low: Double
        var high: Double
        var id: Double { ageYears }
    }

    let points: [SeriesPoint]
    let unit: HeightUnit
    let xDomain: ClosedRange<Double>
    let yDomain: ClosedRange<Double>
    let outerBand: [BandPoint]
    let innerBand: [BandPoint]
    let median: [BandPoint]

    init(series: GrowthSeries, sex: ReferenceSex, unit: HeightUnit, ageNowYears: Double, window: ChartWindow, reference: GrowthReference = ReferenceRegistry.cdc2000) {
        let points = series.chartablePoints
        self.points = points
        self.unit = unit

        var lower = 2.0
        var upper = 20.0
        if window == .focus, let first = points.first, let last = points.last {
            lower = max(2, first.ageMonths / 12 - 1)
            upper = min(20, max(last.ageMonths / 12, min(ageNowYears, 20)) + 2)
            if upper - lower < 4 {
                let missing = 4 - (upper - lower)
                lower = max(2, lower - missing / 2)
                upper = min(20, lower + 4)
            }
        }
        xDomain = lower...upper

        let curves = ReferenceCurves.curves(sex: sex, reference: reference, ageMonths: (lower * 12)...(upper * 12),
                                            lines: [.p3, .p25, .p50, .p75, .p97])
        func line(_ p: MajorPercentile) -> [ReferenceCurve.Point] { curves.first { $0.line == p }?.points ?? [] }
        func convert(_ cm: Double) -> Double { unit == .centimeters ? cm : cm / HeightConversion.centimetersPerInch }
        let p3 = line(.p3), p25 = line(.p25), p50 = line(.p50), p75 = line(.p75), p97 = line(.p97)
        outerBand = zip(p3, p97).map { BandPoint(ageYears: $0.ageMonths / 12, low: convert($0.heightCm), high: convert($1.heightCm)) }
        innerBand = zip(p25, p75).map { BandPoint(ageYears: $0.ageMonths / 12, low: convert($0.heightCm), high: convert($1.heightCm)) }
        median = p50.map { BandPoint(ageYears: $0.ageMonths / 12, low: convert($0.heightCm), high: convert($0.heightCm)) }

        let visibleHeights = points.filter { (lower...upper).contains($0.ageMonths / 12) }.map { convert($0.heightCm) }
        let minY = min(outerBand.map(\.low).min() ?? 0, visibleHeights.min() ?? .infinity)
        let maxY = max(outerBand.map(\.high).max() ?? 1, visibleHeights.max() ?? -.infinity)
        let pad = (maxY - minY) * 0.06
        yDomain = (minY - pad)...(maxY + pad)
    }

    func display(_ cm: Double) -> Double { unit == .centimeters ? cm : cm / HeightConversion.centimetersPerInch }
}

struct GrowthChartView: View {
    let model: GrowthChartModel
    @Binding var selected: SeriesPoint?
    @State private var rawSelection: Double?

    var body: some View {
        Chart {
            ForEach(model.outerBand) { p in
                AreaMark(x: .value("Age", p.ageYears), yStart: .value("3rd percentile", p.low), yEnd: .value("97th percentile", p.high), series: .value("Band", "outer"))
                    .foregroundStyle(DS.Colors.accent.opacity(0.07))
                    .interpolationMethod(.monotone)
            }
            ForEach(model.innerBand) { p in
                AreaMark(x: .value("Age", p.ageYears), yStart: .value("25th percentile", p.low), yEnd: .value("75th percentile", p.high), series: .value("Band", "inner"))
                    .foregroundStyle(DS.Colors.accent.opacity(0.10))
                    .interpolationMethod(.monotone)
            }
            ForEach(model.median) { p in
                LineMark(x: .value("Age", p.ageYears), y: .value("Height", p.low), series: .value("Line", "median"))
                    .foregroundStyle(DS.Colors.textTertiary.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .interpolationMethod(.monotone)
            }
            ForEach(model.points) { point in
                LineMark(x: .value("Age", point.ageMonths / 12), y: .value("Height", model.display(point.heightCm)), series: .value("Line", "you"))
                    .foregroundStyle(DS.Colors.accent)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
            ForEach(model.points) { point in
                PointMark(x: .value("Age", point.ageMonths / 12), y: .value("Height", model.display(point.heightCm)))
                    .foregroundStyle(point.quality == .estimate ? DS.Colors.accent.opacity(0.45) : DS.Colors.accent)
                    .symbolSize(point.id == selected?.id ? 160 : 70)
                    .accessibilityLabel("Age \(GrowthCopy.ageText(months: point.ageMonths))")
                    .accessibilityValue(accessibilityValue(for: point))
            }
            if let selected {
                RuleMark(x: .value("Age", selected.ageMonths / 12))
                    .foregroundStyle(DS.Colors.textTertiary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartXScale(domain: model.xDomain)
        .chartYScale(domain: model.yDomain)
        .chartXAxisLabel("Age (years)")
        .chartYAxisLabel(model.unit == .centimeters ? "cm" : "in")
        .chartLegend(.hidden)
        .chartXSelection(value: $rawSelection)
        .onChange(of: rawSelection) { _, age in
            guard let age else { return }
            selected = model.points.min { abs($0.ageMonths / 12 - age) < abs($1.ageMonths / 12 - age) }
        }
        .frame(height: 260)
        .accessibilityChartDescriptor(GrowthChartDescriptor(model: model))
    }

    private func accessibilityValue(for point: SeriesPoint) -> String {
        var parts = [HeightFormatter.accessibleString(centimeters: point.heightCm, unit: model.unit)]
        if let p = point.percentile { parts.append(PercentileFormatter.phrase(p.percentile)) }
        if point.quality == .estimate { parts.append("estimated") }
        return parts.joined(separator: ", ")
    }
}

/// VoiceOver audio graph: the person's measurements as a continuous series.
struct GrowthChartDescriptor: AXChartDescriptorRepresentable {
    let model: GrowthChartModel

    func makeChartDescriptor() -> AXChartDescriptor {
        let unitName = model.unit == .centimeters ? "centimetres" : "inches"
        let xAxis = AXNumericDataAxisDescriptor(title: "Age in years", range: model.xDomain, gridlinePositions: []) { value in
            String(format: "%.1f years", value)
        }
        let yAxis = AXNumericDataAxisDescriptor(title: "Height in \(unitName)", range: model.yDomain, gridlinePositions: []) { value in
            String(format: "%.1f \(unitName)", value)
        }
        let series = AXDataSeriesDescriptor(name: "Measurements", isContinuous: true, dataPoints: model.points.map {
            AXDataPoint(x: $0.ageMonths / 12, y: model.display($0.heightCm))
        })
        return AXChartDescriptor(title: "Growth chart", summary: "Your measurements over the CDC percentile bands. Shaded area: 3rd to 97th percentile.",
                                 xAxis: xAxis, yAxis: yAxis, additionalAxes: [], series: [series])
    }
}

/// Detail for the tapped point.
struct SelectedPointDetail: View {
    let point: SeriesPoint
    let unit: HeightUnit

    var body: some View {
        HStack(spacing: DS.Spacing.lg) {
            detail("Age", GrowthCopy.ageText(months: point.ageMonths))
            detail("Height", HeightFormatter.string(centimeters: point.heightCm, unit: unit))
            detail("Percentile", point.percentile.map { PercentileFormatter.ordinal($0.percentile) } ?? "—")
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.sm)
        .background(DS.Colors.surfaceSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if point.quality == .estimate { Badge("Estimate", tone: .caution).padding(6) }
        }
        .accessibilityElement(children: .combine)
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
            Text(value).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary).monospacedDigit()
        }
    }
}

struct ChartLegend: View {
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            legendItem(color: DS.Colors.accent, label: "You", isLine: true)
            legendItem(color: DS.Colors.accent.opacity(0.18), label: "25th–75th")
            legendItem(color: DS.Colors.accent.opacity(0.08), label: "3rd–97th")
            HStack(spacing: 4) {
                Rectangle().fill(DS.Colors.textTertiary).frame(width: 14, height: 1)
                Text("50th")
            }
        }
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.textSecondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Legend: your line, 25th to 75th percentile band, 3rd to 97th percentile band, dashed 50th percentile")
    }

    private func legendItem(color: Color, label: String, isLine: Bool = false) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 14, height: isLine ? 3 : 10)
            Text(label)
        }
    }
}
#endif
