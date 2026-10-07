#if os(iOS)
import SwiftUI

/// The signature visual: a vertical "door-frame" ruler showing where a height sits among the CDC percentile
/// lines (3rd at the bottom, 97th at the top) with the 25th–75th band shaded. It shows position, not a score;
/// nothing on it can be "filled up" or levelled.
public struct DoorFrameRuler: View {
    /// z-score of the current position, or nil when no percentile exists (e.g. adults).
    let z: Double?
    let markerLabel: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    public init(z: Double?, markerLabel: String?) {
        self.z = z
        self.markerLabel = markerLabel
    }

    // Major line z-scores (3, 10, 25, 50, 75, 90, 97).
    private let lines: [(Double, String?)] = [(-1.881, "3rd"), (-1.282, nil), (-0.674, "25th"), (0, "50th"), (0.674, "75th"), (1.282, nil), (1.881, "97th")]
    private let span = 2.4

    private func y(_ z: Double, height: CGFloat) -> CGFloat {
        let clamped = min(max(z, -span), span)
        return height * CGFloat((span - clamped) / (2 * span))
    }

    public var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height
            let w = proxy.size.width
            ZStack(alignment: .topLeading) {
                // Frame edge.
                RoundedRectangle(cornerRadius: 2)
                    .fill(DS.Colors.separator)
                    .frame(width: 3, height: h)
                    .offset(x: 10)
                // 25th–75th band.
                RoundedRectangle(cornerRadius: 3)
                    .fill(DS.Colors.accentSoft)
                    .frame(width: 18, height: y(-0.674, height: h) - y(0.674, height: h))
                    .offset(x: 3, y: y(0.674, height: h))
                // Ticks and labels.
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    let isMajor = line.1 != nil
                    Rectangle()
                        .fill(DS.Colors.textTertiary.opacity(isMajor ? 0.8 : 0.4))
                        .frame(width: isMajor ? 14 : 8, height: 1)
                        .offset(x: isMajor ? 4 : 7, y: y(line.0, height: h))
                    if let label = line.1 {
                        Text(label)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(DS.Colors.textTertiary)
                            .fixedSize()
                            .offset(x: 24, y: y(line.0, height: h) - 7)
                    }
                }
                // Marker.
                if let z {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(DS.Colors.accent)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(DS.Colors.surface, lineWidth: 3))
                            .shadow(color: DS.Colors.accent.opacity(0.35), radius: 6)
                        if let markerLabel {
                            Text(markerLabel)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(DS.Colors.onAccent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DS.Colors.accent, in: Capsule())
                                .fixedSize()
                        }
                    }
                    .offset(x: 4.5, y: (appeared || reduceMotion ? y(z, height: h) : h) - 7)
                }
            }
            .frame(width: w, height: h, alignment: .topLeading)
        }
        .frame(width: 84)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82).delay(0.1)) { appeared = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(markerLabel.map { "Position on the CDC growth chart: \($0) percentile" } ?? "Growth chart position not available")
    }
}

/// Seven days of check-ins as dots; partially completed days are partially filled. Never red.
public struct WeekDots: View {
    public struct Day: Identifiable {
        public var id: Date
        public var letter: String
        public var fraction: Double
        public var isToday: Bool
        public init(id: Date, letter: String, fraction: Double, isToday: Bool) {
            self.id = id; self.letter = letter; self.fraction = fraction; self.isToday = isToday
        }
    }
    let days: [Day]
    let size: CGFloat

    public init(days: [Day], size: CGFloat = 28) {
        self.days = days
        self.size = size
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    ZStack {
                        Circle().fill(DS.Colors.surfaceSecondary)
                        Circle()
                            .trim(from: 0, to: day.fraction)
                            .stroke(DS.Colors.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        if day.fraction >= 1 {
                            Circle().fill(DS.Colors.accent).padding(5)
                            Image(systemName: "checkmark").font(.system(size: size * 0.32, weight: .bold)).foregroundStyle(DS.Colors.onAccent)
                        }
                    }
                    .frame(width: size, height: size)
                    .overlay(Circle().stroke(day.isToday ? DS.Colors.textPrimary.opacity(0.35) : .clear, lineWidth: 1).padding(-3))
                    Text(day.letter)
                        .font(.system(size: 11, weight: day.isToday ? .bold : .medium, design: .rounded))
                        .foregroundStyle(day.isToday ? DS.Colors.textPrimary : DS.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.letter), \(Int((day.fraction * 100).rounded())) percent of habits\(day.isToday ? ", today" : "")")
            }
        }
        .animation(Motion.standard, value: days.map(\.fraction))
    }
}

/// Four weeks of check-in intensity. Empty days are neutral grey, not a failure colour.
public struct ConsistencyGrid: View {
    let fractions: [Double]

    public init(fractions: [Double]) {
        self.fractions = fractions
    }

    public var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(fractions.enumerated()), id: \.offset) { _, f in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(f > 0 ? DS.Colors.accent.opacity(0.25 + 0.75 * f) : DS.Colors.surfaceSecondary)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Check-ins over the last four weeks: \(fractions.filter { $0 > 0 }.count) of \(fractions.count) days")
    }
}

/// Small ring for "time since last measurement" against the suggested interval.
public struct IntervalRing: View {
    let fraction: Double
    let label: String

    public init(fraction: Double, label: String) {
        self.fraction = fraction
        self.label = label
    }

    public var body: some View {
        ZStack {
            Circle().stroke(DS.Colors.surfaceSecondary, lineWidth: 5)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0.02), 1))
                .stroke(DS.Colors.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(DS.Colors.textPrimary)
                .minimumScaleFactor(0.7)
                .padding(6)
        }
        .frame(width: 46, height: 46)
        .accessibilityHidden(true)
    }
}

/// A large tappable check-in row. Completing it gives a soft haptic and a quick symbol bounce.
public struct CheckInRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let isDone: Bool
    let action: () -> Void

    public init(title: String, subtitle: String, symbol: String, isDone: Bool, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.isDone = isDone
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: symbol)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(isDone ? DS.Colors.onAccent : DS.Colors.accent)
                    .frame(width: 40, height: 40)
                    .background(isDone ? DS.Colors.accent : DS.Colors.accentSoft, in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    .accessibilityHidden(true)
                    .hiddenAtAccessibilitySizes()
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                    Text(subtitle).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: DS.Spacing.xs)
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundStyle(isDone ? DS.Colors.accent : DS.Colors.separator)
                    .symbolEffect(.bounce, value: isDone)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, DS.Spacing.sm)
            .padding(.horizontal, DS.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.success, trigger: isDone) { _, new in new }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isDone ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isDone ? "Marks as not done" : "Marks as done for today")
    }
}

/// Calm success mark used after saving or completing.
public struct SuccessSeal: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    public init() {}

    public var body: some View {
        ZStack {
            Circle().fill(DS.Colors.accentSoft).frame(width: 96, height: 96)
                .scaleEffect(shown || reduceMotion ? 1 : 0.6)
            Image(systemName: "checkmark")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(DS.Colors.accent)
                .scaleEffect(shown || reduceMotion ? 1 : 0.3)
                .opacity(shown || reduceMotion ? 1 : 0)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) { shown = true }
        }
        .sensoryFeedback(.success, trigger: shown)
        .accessibilityHidden(true)
    }
}

/// Hero surface: a very soft tint from the top-leading corner. Used once per screen at most.
public struct HeroSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    DS.Colors.surface
                    LinearGradient(colors: [DS.Colors.accentSoft.opacity(colorScheme == .dark ? 0.9 : 0.75), DS.Colors.surface.opacity(0)],
                                   startPoint: .topLeading, endPoint: .center)
                },
                in: RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous).strokeBorder(DS.Colors.separator.opacity(colorScheme == .dark ? 1 : 0.6), lineWidth: 0.5))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 16, x: 0, y: 6)
    }
}

public extension View {
    func heroSurface() -> some View { modifier(HeroSurface()) }
}
#endif
