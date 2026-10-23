#if os(iOS)
import SwiftUI

/// A circular progress ring with a champagne gradient stroke. Animates its fill with a spring, and simply
/// appears filled under Reduce Motion.
public struct ProgressRing<Center: View>: View {
    let progress: Double
    let lineWidth: CGFloat
    let center: Center
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = 0

    public init(progress: Double, lineWidth: CGFloat = 10, @ViewBuilder center: () -> Center) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.center = center()
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(DS.Colors.surfaceSecondary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, shown)))
                .stroke(
                    AngularGradient(colors: [DS.Colors.accent.opacity(0.55), DS.Colors.accent, DS.Colors.accent], center: .center,
                                    startAngle: .degrees(0), endAngle: .degrees(360 * max(0.05, shown))),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            center
        }
        .onAppear { animate(to: progress, delay: 0.1) }
        .onChange(of: progress) { _, value in animate(to: value, delay: 0) }
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(Int((min(1, max(0, progress)) * 100).rounded())) percent")
    }

    private func animate(to value: Double, delay: Double) {
        if reduceMotion { shown = value; return }
        withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(delay)) { shown = value }
    }
}

public extension ProgressRing where Center == EmptyView {
    init(progress: Double, lineWidth: CGFloat = 10) {
        self.init(progress: progress, lineWidth: lineWidth) { EmptyView() }
    }
}

/// A square tile for a tool (Posture check, Bedtime…): symbol, title, one line of status, optional Pro badge.
public struct ToolTile: View {
    let symbol: String
    let title: String
    let status: String
    let isLocked: Bool
    let action: () -> Void

    public init(symbol: String, title: String, status: String, isLocked: Bool = false, action: @escaping () -> Void) {
        self.symbol = symbol
        self.title = title
        self.status = status
        self.isLocked = isLocked
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(alignment: .top) {
                    Image(systemName: symbol)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(DS.Colors.accent)
                        .frame(width: 40, height: 40)
                        .background(DS.Colors.accentSoft, in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                        .accessibilityHidden(true)
                    Spacer(minLength: 0)
                    if isLocked { PremiumBadge() }
                }
                Spacer(minLength: 0)
                Text(title).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                Text(status).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
            .dsSurface()
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(isLocked ? "Part of Gromax Pro" : "")
    }
}

/// Level chip: "Lv 3 · Consistent" with a thin progress bar underneath.
public struct LevelChip: View {
    let level: Int
    let name: String
    let progress: Double

    public init(level: Int, name: String, progress: Double) {
        self.level = level
        self.name = name
        self.progress = progress
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.caption.weight(.semibold))
                Text("Lv \(level) · \(name)").font(DS.Typography.caption.weight(.semibold))
            }
            .foregroundStyle(DS.Colors.accent)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(DS.Colors.surfaceSecondary)
                    Capsule().fill(DS.Colors.accent).frame(width: max(4, proxy.size.width * min(1, max(0, progress))))
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .frame(width: 148)
        .background(DS.Colors.accentSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(level), \(name), \(Int((progress * 100).rounded())) percent to the next level")
    }
}

/// A slow, subtle breathing glow behind hero content. Static under Reduce Motion.
public struct AmbientGlow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = false

    public init() {}

    public var body: some View {
        Circle()
            .fill(RadialGradient(colors: [DS.Colors.accent.opacity(0.28), .clear], center: .center, startRadius: 0, endRadius: 160))
            .scaleEffect(phase ? 1.08 : 0.92)
            .opacity(phase ? 1 : 0.75)
            .blur(radius: 8)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) { phase = true }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
#endif
