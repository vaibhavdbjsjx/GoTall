#if os(iOS)
import SwiftUI

public struct OnboardingProgressModel: Equatable {
    public var chapters: [String]
    public var currentIndex: Int
    public var fractionWithinChapter: Double

    public init(chapters: [String], currentIndex: Int, fractionWithinChapter: Double) {
        self.chapters = chapters
        self.currentIndex = currentIndex
        self.fractionWithinChapter = fractionWithinChapter
    }
}

/// Shared frame for every onboarding step: top bar (back, chapter progress, skip),
/// scrollable question area, and a pinned footer for the primary action.
public struct OnboardingContainer<Content: View, Footer: View>: View {
    let progress: OnboardingProgressModel?
    let title: String?
    let subtitle: String?
    let canGoBack: Bool
    let onBack: () -> Void
    let skipTitle: String?
    let onSkip: (() -> Void)?
    let content: Content
    let footer: Footer

    public init(
        progress: OnboardingProgressModel?,
        title: String?,
        subtitle: String? = nil,
        canGoBack: Bool,
        onBack: @escaping () -> Void,
        skipTitle: String? = nil,
        onSkip: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.progress = progress
        self.title = title
        self.subtitle = subtitle
        self.canGoBack = canGoBack
        self.onBack = onBack
        self.skipTitle = skipTitle
        self.onSkip = onSkip
        self.content = content()
        self.footer = footer()
    }

    public var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, DS.Spacing.xs)
                .padding(.top, DS.Spacing.xs)

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    if title != nil || subtitle != nil {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            if let title {
                                Text(title)
                                    .font(DS.Typography.question)
                                    .foregroundStyle(DS.Colors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityAddTraits(.isHeader)
                            }
                            if let subtitle {
                                Text(subtitle)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(DS.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    content
                }
                .padding(.horizontal, DS.Spacing.page)
                .padding(.top, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.xxl)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: DS.Spacing.xs) {
                footer
            }
            .padding(.horizontal, DS.Spacing.page)
            .padding(.top, DS.Spacing.sm)
            .padding(.bottom, DS.Spacing.xs)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
            .background(DS.Colors.background.opacity(0.96).ignoresSafeArea(edges: .bottom))
        }
        .dsPageBackground()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { dismissKeyboard() }
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: DS.Spacing.xs) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
                    .foregroundStyle(DS.Colors.textPrimary)
            }
            .opacity(canGoBack ? 1 : 0)
            .disabled(!canGoBack)
            .accessibilityLabel("Back")
            .accessibilityHidden(!canGoBack)

            if let progress {
                ChapterProgressView(chapters: progress.chapters, currentIndex: progress.currentIndex, fractionWithinChapter: progress.fractionWithinChapter)
                    .frame(maxWidth: .infinity)
            } else {
                Spacer()
            }

            Group {
                if let skipTitle, let onSkip {
                    Button(skipTitle, action: onSkip)
                        .font(DS.Typography.subheadline.weight(.semibold))
                        .foregroundStyle(DS.Colors.textSecondary)
                } else {
                    Color.clear
                }
            }
            .frame(minWidth: DS.minimumTapTarget, minHeight: DS.minimumTapTarget)
        }
    }
}
#endif
