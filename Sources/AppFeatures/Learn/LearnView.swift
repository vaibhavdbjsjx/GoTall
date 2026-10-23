#if os(iOS)
import SwiftUI
import GrowthCore
import DesignSystem

/// Short, sourced reads. A few are free; the full library is part of Gromax Pro.
struct LearnView: View {
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(AppNavigator.self) private var navigator

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    Text("Straight answers about growth, sleep, food and posture, each linked to the public-health source it's based on.")
                        .font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                    if let featured = ArticleLibrary.all.first {
                        NavigationLink(value: featured.id) { FeaturedArticleCard(article: featured) }
                            .buttonStyle(PressableStyle())
                            .appearEffect()
                    }
                    VStack(spacing: DS.Spacing.sm) {
                        ForEach(Array(ArticleLibrary.all.dropFirst().enumerated()), id: \.element.id) { index, article in
                            let locked = !article.isFree && entitlements.access(.learnLibrary) != .available
                            Group {
                                if locked {
                                    Button { navigator.showPaywall(.learn) } label: { ArticleRow(article: article, isLocked: true) }
                                } else {
                                    NavigationLink(value: article.id) { ArticleRow(article: article, isLocked: false) }
                                }
                            }
                            .buttonStyle(PressableStyle())
                            .appearEffect(delay: min(0.15, Double(index) * 0.02))
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.page)
                .padding(.vertical, DS.Spacing.md)
            }
            .dsPageBackground()
            .navigationTitle("Learn")
            .navigationDestination(for: String.self) { id in
                if let article = ArticleLibrary.article(id: id) { ArticleView(article: article) }
            }
        }
    }
}

private struct FeaturedArticleCard: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("START HERE").font(DS.Typography.eyebrow).foregroundStyle(DS.Colors.accent)
                Spacer()
                Image(systemName: article.symbol).font(.title2).foregroundStyle(DS.Colors.accent)
            }
            Text(article.title).font(DS.Typography.title).foregroundStyle(DS.Colors.textPrimary).multilineTextAlignment(.leading)
            Text(article.summary).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary).multilineTextAlignment(.leading)
            Text("\(article.minutes) min read").font(DS.Typography.caption).foregroundStyle(DS.Colors.textTertiary)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .heroSurface()
    }
}

private struct ArticleRow: View {
    let article: Article
    let isLocked: Bool

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: article.symbol)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(DS.Colors.accent)
                .frame(width: 44, height: 44)
                .background(DS.Colors.accentSoft, in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(article.title).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary).multilineTextAlignment(.leading)
                Text(article.summary).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary).multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            if isLocked { PremiumBadge() } else {
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(DS.Colors.textTertiary)
            }
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsSurface()
        .accessibilityElement(children: .combine)
    }
}

struct ArticleView: View {
    let article: Article

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Text("\(article.minutes) MIN READ").font(DS.Typography.eyebrow).foregroundStyle(DS.Colors.accent)
                Text(article.title).font(DS.Typography.display).foregroundStyle(DS.Colors.textPrimary)
                Text(article.summary).font(DS.Typography.title).foregroundStyle(DS.Colors.textSecondary)
                ForEach(Array(article.paragraphs.enumerated()), id: \.offset) { index, paragraph in
                    Text(paragraph).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .appearEffect(delay: min(0.12, Double(index) * 0.04))
                }
                if let url = article.sourceURL {
                    Link(destination: url) {
                        Label("Source: \(article.sourceName)", systemImage: "link")
                            .font(DS.Typography.subheadline.weight(.semibold))
                            .multilineTextAlignment(.leading)
                    }
                    .tint(DS.Colors.accent)
                }
                Text("General information, not medical advice. Talk to a doctor about any concern.")
                    .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textTertiary)
            }
            .padding(DS.Spacing.page)
        }
        .dsPageBackground()
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
