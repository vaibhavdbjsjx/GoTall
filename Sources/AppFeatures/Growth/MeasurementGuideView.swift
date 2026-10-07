#if os(iOS)
import SwiftUI
import DesignSystem

/// Visual guide to measuring height at home. Original illustration drawn in code.
struct MeasurementGuideView: View {
    @Environment(\.dismiss) private var dismiss

    private let steps: [(symbol: String, title: String, detail: String)] = [
        ("shoeprints.fill", "Barefoot, hair flat", "Remove shoes and anything on top of the head, like a ponytail or hat."),
        ("square.split.bottomrightquarter", "Hard, flat floor", "Stand on a hard floor, not carpet, against a flat wall without skirting boards if you can."),
        ("figure.stand", "Stand tall, naturally", "Heels together and touching the wall, with the back of the legs, bottom and shoulders against it too."),
        ("eye", "Head level", "Look straight ahead so the line from the ear to the bottom of the eye socket is level, not tilted up or down."),
        ("book.closed", "Mark with a flat object", "Rest a book flat on the head, square to the wall, and mark lightly underneath it."),
        ("arrow.clockwise", "Measure twice", "Measure from the floor to the mark, repeat once, and use the average. Same time of day each time.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    MeasuringIllustration()
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                        .accessibilityLabel("Illustration: a person standing straight against a wall with a book resting flat on their head")

                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: DS.Spacing.md) {
                                ZStack {
                                    Circle().fill(DS.Colors.accentSoft)
                                    Image(systemName: step.symbol).foregroundStyle(DS.Colors.accent)
                                }
                                .frame(width: 44, height: 44)
                                .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(index + 1). \(step.title)").font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                                    Text(step.detail).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .appearEffect(delay: Double(index) * 0.03)
                        }
                    }

                    InfoBanner("Most people are slightly taller in the morning than in the evening. Measuring at the same time of day keeps your chart consistent.", title: "Why consistency matters")
                    InfoBanner("A doctor, nurse or school measurement with a proper stadiometer is the most accurate. You can record its method when you add it.", title: "Best accuracy")
                }
                .padding(DS.Spacing.page)
            }
            .dsPageBackground()
            .navigationTitle("Measuring at home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

/// Simple, original line illustration: wall, floor, standing figure, book at a right angle with a mark.
struct MeasuringIllustration: View {
    var body: some View {
        Canvas { context, size in
            let accent = GraphicsContext.Shading.color(DS.Colors.accent)
            let ink = GraphicsContext.Shading.color(DS.Colors.textSecondary)
            let soft = GraphicsContext.Shading.color(DS.Colors.accentSoft)
            let floorY = size.height * 0.9
            let wallX = size.width * 0.38
            let top = size.height * 0.12

            // Wall and floor.
            var wall = Path(); wall.move(to: CGPoint(x: wallX, y: top - 10)); wall.addLine(to: CGPoint(x: wallX, y: floorY))
            context.stroke(wall, with: ink, lineWidth: 2)
            var floor = Path(); floor.move(to: CGPoint(x: size.width * 0.15, y: floorY)); floor.addLine(to: CGPoint(x: size.width * 0.85, y: floorY))
            context.stroke(floor, with: ink, lineWidth: 2)

            // Figure (abstract): head, body, legs touching the wall.
            let headR = size.height * 0.07
            let headCenter = CGPoint(x: wallX + headR + 2, y: top + headR + 6)
            context.fill(Path(ellipseIn: CGRect(x: headCenter.x - headR, y: headCenter.y - headR, width: headR * 2, height: headR * 2)), with: soft)
            context.stroke(Path(ellipseIn: CGRect(x: headCenter.x - headR, y: headCenter.y - headR, width: headR * 2, height: headR * 2)), with: accent, lineWidth: 2)
            let bodyRect = CGRect(x: wallX + 2, y: headCenter.y + headR + 4, width: headR * 1.8, height: (floorY - headCenter.y) * 0.45)
            context.fill(Path(roundedRect: bodyRect, cornerRadius: 10), with: soft)
            context.stroke(Path(roundedRect: bodyRect, cornerRadius: 10), with: accent, lineWidth: 2)
            var legs = Path()
            legs.move(to: CGPoint(x: bodyRect.minX + headR * 0.5, y: bodyRect.maxY)); legs.addLine(to: CGPoint(x: bodyRect.minX + headR * 0.5, y: floorY))
            legs.move(to: CGPoint(x: bodyRect.minX + headR * 1.3, y: bodyRect.maxY)); legs.addLine(to: CGPoint(x: bodyRect.minX + headR * 1.3, y: floorY))
            context.stroke(legs, with: accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))

            // Book resting flat on the head, square to the wall.
            let bookY = headCenter.y - headR - 2
            let book = CGRect(x: wallX, y: bookY - 8, width: headR * 3.2, height: 8)
            context.fill(Path(roundedRect: book, cornerRadius: 2), with: accent)
            // Right-angle marker.
            var corner = Path()
            corner.move(to: CGPoint(x: wallX + 10, y: bookY - 8)); corner.addLine(to: CGPoint(x: wallX + 10, y: bookY - 18)); corner.addLine(to: CGPoint(x: wallX, y: bookY - 18))
            context.stroke(corner, with: ink, lineWidth: 1)
            // Mark on the wall and measuring line.
            var mark = Path(); mark.move(to: CGPoint(x: wallX - 14, y: bookY)); mark.addLine(to: CGPoint(x: wallX, y: bookY))
            context.stroke(mark, with: accent, lineWidth: 3)
            var tape = Path(); tape.move(to: CGPoint(x: wallX - 24, y: bookY)); tape.addLine(to: CGPoint(x: wallX - 24, y: floorY))
            context.stroke(tape, with: ink, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            for i in 0...8 {
                let y = floorY - CGFloat(i) * (floorY - bookY) / 8
                var tick = Path(); tick.move(to: CGPoint(x: wallX - 28, y: y)); tick.addLine(to: CGPoint(x: wallX - 20, y: y))
                context.stroke(tick, with: ink, lineWidth: 1)
            }
        }
    }
}
#endif
