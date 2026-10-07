#if os(iOS)
import SwiftUI
import QuickLook
import GrowthCore
import DesignSystem

/// Shows exactly what the doctor-ready report will contain, from the person's current data, before
/// anything is generated. Free users can see the full preview; generating the PDF is Premium.
struct ReportPreviewView: View {
    let repository: AppRepository
    @Environment(EntitlementStore.self) private var entitlements
    @State private var unit: HeightUnit?
    @State private var phase: Phase = .idle
    @State private var quickLookURL: URL?
    @State private var paywall: PaywallContext?

    enum Phase: Equatable {
        case idle
        case generating
        case ready(URL)
        case failed
    }

    var body: some View {
        Group {
            if let profile = repository.activeProfile {
                content(profile)
            } else {
                EmptyStateView(systemImage: "doc.richtext", title: "No profile yet", message: "Add a profile to create a report.")
            }
        }
        .dsPageBackground()
        .navigationTitle("Growth report")
        .navigationBarTitleDisplayMode(.inline)
        .quickLookPreview($quickLookURL)
        .paywallSheet($paywall)
        .onChange(of: repository.activeProfile?.id) { _, _ in phase = .idle }
        .onChange(of: entitlements.isPremium) { _, _ in phase = .idle }
        .task {
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "reportAutoGenerate"), let profile = repository.activeProfile, entitlements.isPremium {
                await generate(profile)
            }
            #endif
        }
    }

    private func content(_ profile: GrowthProfile) -> some View {
        let now = Date()
        let selectedUnit = unit ?? profile.unitPreference
        let report = GrowthReportBuilder(now: now, calendar: .current).build(profile: profile, unit: selectedUnit)
        return ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                header(profile, report: report)
                    .appearEffect()
                AppCard {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text("Units").font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                        SegmentedChoice("Report units", options: [HeightUnit.centimeters, .feetInches], selection: Binding(
                            get: { selectedUnit }, set: { unit = $0; phase = .idle })) { $0 == .centimeters ? "Centimetres" : "Feet and inches" }
                        if selectedUnit == .feetInches {
                            Text("Centimetres are shown in brackets, as clinicians usually use them.")
                                .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                        }
                    }
                }
                sections(report)
                dataSummary(profile, report: report)
                QuietNote(title: "Not a diagnosis", message: "The report presents measurements and growth-chart context for a conversation with a healthcare professional. It states clearly that it isn't a diagnosis and that estimates aren't guarantees.", symbol: "stethoscope")
                actionArea(profile)
            }
            .padding(.horizontal, DS.Spacing.page)
            .padding(.vertical, DS.Spacing.md)
        }
    }

    private func header(_ profile: GrowthProfile, report: GrowthReport) -> some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            ReportPreview(compact: true)
                .hiddenAtAccessibilitySizes()
            VStack(alignment: .leading, spacing: 4) {
                AdaptiveStack(horizontalAlignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                    Text("Doctor-ready report").font(DS.Typography.title).foregroundStyle(DS.Colors.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if !entitlements.isPremium { PremiumBadge() }
                }
                Text("For \(profile.displayLabel) · \(report.sections.count) sections · US Letter PDF")
                    .font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                if let latest = profile.latestMeasurement {
                    Text("Data up to \(DisplayFormat.day(latest.date, calendar: .current))")
                        .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textTertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .heroSurface()
    }

    private func sections(_ report: GrowthReport) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionHeader("What's included")
            AppCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(report.sections) { section in
                        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                            Text(String(format: "%02d", section.number))
                                .font(DS.Typography.caption.monospacedDigit())
                                .foregroundStyle(DS.Colors.accent)
                                .frame(width: 24, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(section.title).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
                                if case .limited(let note) = section.status {
                                    Text(note).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: section.status == .included ? "checkmark.circle.fill" : "minus.circle")
                                .foregroundStyle(section.status == .included ? DS.Colors.accent : DS.Colors.textTertiary)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .accessibilityElement(children: .combine)
                        if section.number < report.sections.count { Divider().padding(.leading, DS.Spacing.md + 24 + DS.Spacing.sm) }
                    }
                }
            }
            .accessibilityIdentifier("report.sections")
        }
    }

    private func dataSummary(_ profile: GrowthProfile, report: GrowthReport) -> some View {
        let measurements = profile.sortedMeasurements
        let range: String = {
            guard let first = measurements.first, let last = measurements.last else { return "No measurements" }
            if first.id == last.id { return DisplayFormat.day(first.date, calendar: .current) }
            return "\(DisplayFormat.monthYear(first.date, calendar: .current)) – \(DisplayFormat.monthYear(last.date, calendar: .current))"
        }()
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionHeader("From your data")
            AppCard {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    LabeledContent("Measurements", value: "\(measurements.count)")
                    LabeledContent("Period", value: range)
                    LabeledContent("Current height", value: report.current.first { $0.label == "Height" }?.value ?? "—")
                    LabeledContent("Reference", value: "CDC 2000")
                }
                .font(DS.Typography.subheadline)
                .foregroundStyle(DS.Colors.textPrimary)
            }
            Label("Made on this iPhone. Nothing is uploaded.", systemImage: "lock")
                .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
        }
    }

    @ViewBuilder
    private func actionArea(_ profile: GrowthProfile) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            switch phase {
            case .ready(let url):
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(DS.Colors.accent)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Report ready").font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                                .accessibilityIdentifier("report.ready")
                            Text(url.lastPathComponent).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    AppButton("View report", systemImage: "doc.text.magnifyingglass") { quickLookURL = url }
                    ShareLink(item: url) {
                        Label("Share or print", systemImage: "square.and.arrow.up")
                            .font(DS.Typography.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .foregroundStyle(DS.Colors.accent)
                            .background(DS.Colors.accentSoft, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                    }
                    .accessibilityIdentifier("report.share")
                }
                .padding(DS.Spacing.md)
                .dsSurface()
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .failed:
                InfoBanner("The report couldn't be created. Your data is unchanged. Please try again; if it keeps happening, restart the app.", title: "Something went wrong", tone: .caution)
                generateButton(profile)
            case .idle, .generating:
                generateButton(profile)
                if !entitlements.isPremium {
                    Text("Generating the PDF is part of Premium. Everything shown above stays free to view.")
                        .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .animation(Motion.standard, value: phase)
    }

    private func generateButton(_ profile: GrowthProfile) -> some View {
        AppButton(phase == .generating ? "Preparing report" : "Generate report", systemImage: "doc.richtext", isLoading: phase == .generating) {
            if entitlements.access(.doctorReport) == .available {
                Task { await generate(profile) }
            } else {
                paywall = .report
            }
        }
        .accessibilityIdentifier("report.generate")
    }

    private func generate(_ profile: GrowthProfile) async {
        phase = .generating
        let selectedUnit = unit ?? profile.unitPreference
        let now = Date()
        let report = GrowthReportBuilder(now: now, calendar: .current).build(profile: profile, unit: selectedUnit)
        do {
            // Rendering runs off the main thread so the interface stays responsive.
            let data = try await Task.detached(priority: .userInitiated) { try ReportPDFRenderer.render(report) }.value
            let day = ISO8601DateFormatter.string(from: now, timeZone: .current, formatOptions: [.withFullDate])
            let name = "Growth report – \(profile.displayLabel) – \(day).pdf"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            phase = .ready(url)
        } catch {
            phase = .failed
        }
    }
}
#endif
