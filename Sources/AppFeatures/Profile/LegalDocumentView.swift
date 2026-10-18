#if os(iOS)
import SwiftUI
import GrowthCore
import DesignSystem

/// Privacy policy or terms, readable offline inside the app.
struct LegalDocumentView: View {
    let document: LegalDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(document.title).font(DS.Typography.display).foregroundStyle(DS.Colors.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text("\(BrandConfig.current.displayName) · Effective \(document.effectiveDate)")
                            .font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                    }
                    ForEach(document.sections) { section in
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text(section.title).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(section.paragraphs, id: \.self) { paragraph in
                                Text(.init(paragraph))
                                    .font(DS.Typography.body)
                                    .foregroundStyle(DS.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .tint(DS.Colors.accent)
                            }
                        }
                    }
                }
                .padding(DS.Spacing.page)
                .accessibilityIdentifier("legal.\(document.id)")
            }
            .dsPageBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
#endif
