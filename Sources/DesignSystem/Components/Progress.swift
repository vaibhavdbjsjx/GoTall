#if os(iOS)
import SwiftUI

/// Chapter-based progress: five labelled segments that fill as you go.
/// Never shows "step 7 of 31".
public struct ChapterProgressView: View {
    let chapters: [String]
    let currentIndex: Int
    let fractionWithinChapter: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(chapters: [String], currentIndex: Int, fractionWithinChapter: Double) {
        self.chapters = chapters
        self.currentIndex = currentIndex
        self.fractionWithinChapter = fractionWithinChapter
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: 6) {
                ForEach(chapters.indices, id: \.self) { index in
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(DS.Colors.surfaceSecondary)
                            Capsule()
                                .fill(DS.Colors.accent)
                                .frame(width: proxy.size.width * fill(for: index))
                        }
                    }
                    .frame(height: 4)
                }
            }
            .animation(Motion.resolved(Motion.progress, reduceMotion: reduceMotion), value: currentIndex)
            .animation(Motion.resolved(Motion.progress, reduceMotion: reduceMotion), value: fractionWithinChapter)

            Text(chapters.indices.contains(currentIndex) ? chapters[currentIndex].uppercased() : "")
                .font(DS.Typography.eyebrow)
                .tracking(0.6)
                .foregroundStyle(DS.Colors.accent)
                .contentTransition(.opacity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue(chapters.indices.contains(currentIndex)
            ? "\(chapters[currentIndex]), section \(currentIndex + 1) of \(chapters.count)"
            : "")
    }

    private func fill(for index: Int) -> CGFloat {
        if index < currentIndex { return 1 }
        if index > currentIndex { return 0 }
        // A sliver is always shown for the current chapter so it reads as "in progress".
        return CGFloat(max(0.12, fractionWithinChapter))
    }
}
#endif
