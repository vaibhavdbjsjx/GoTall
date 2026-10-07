#if os(iOS)
import SwiftUI

/// Placeholder brand mark: a rising arc over measurement ticks, an original motif
/// (door-frame height marks + growth curve). Replace with the final logo after naming.
public struct BrandMark: View {
    let size: CGFloat

    public init(size: CGFloat = 64) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(DS.Colors.accent)
            Canvas { context, canvasSize in
                let inset = canvasSize.width * 0.22
                let rect = CGRect(origin: .zero, size: canvasSize).insetBy(dx: inset, dy: inset)
                // Ticks on the left edge.
                for index in 0..<4 {
                    let y = rect.maxY - CGFloat(index) * rect.height / 3.4
                    var tick = Path()
                    tick.move(to: CGPoint(x: rect.minX, y: y))
                    tick.addLine(to: CGPoint(x: rect.minX + rect.width * (index.isMultiple(of: 2) ? 0.22 : 0.14), y: y))
                    context.stroke(tick, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: canvasSize.width * 0.035, lineCap: .round))
                }
                // Rising arc.
                var arc = Path()
                arc.move(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.maxY))
                arc.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                                 control: CGPoint(x: rect.maxX * 0.82, y: rect.maxY * 0.98))
                context.stroke(arc, with: .color(.white), style: StrokeStyle(lineWidth: canvasSize.width * 0.075, lineCap: .round))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
#endif
