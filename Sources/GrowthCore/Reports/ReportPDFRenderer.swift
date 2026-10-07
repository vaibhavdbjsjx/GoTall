#if canImport(CoreGraphics) && canImport(CoreText)
import Foundation
import CoreGraphics
import CoreText
import GrowthEngine

/// Renders a `GrowthReport` to a US Letter PDF on the device, with CoreGraphics + CoreText only
/// (no UIKit), so the same code runs in the app and in macOS tests that rasterise the pages for review.
public enum ReportPDFRenderer {
    public static let pageSize = CGSize(width: 612, height: 792)

    public enum RenderError: Error, Equatable {
        case contextUnavailable
    }

    /// Two passes: the first counts pages so every footer can say "Page n of N".
    public static func render(_ report: GrowthReport) throws -> Data {
        let first = try PDFLayout(report: report, totalPages: 0).render()
        return try PDFLayout(report: report, totalPages: first.pages).render().data
    }
}

private enum Ink {
    static var primary: CGColor { CGColor(srgbRed: 0.08, green: 0.10, blue: 0.11, alpha: 1) }
    static var secondary: CGColor { CGColor(srgbRed: 0.34, green: 0.37, blue: 0.39, alpha: 1) }
    static var tertiary: CGColor { CGColor(srgbRed: 0.48, green: 0.51, blue: 0.53, alpha: 1) }
    static var accent: CGColor { CGColor(srgbRed: 0.035, green: 0.44, blue: 0.37, alpha: 1) }
    static var accentSoft: CGColor { CGColor(srgbRed: 0.86, green: 0.94, blue: 0.92, alpha: 1) }
    static var panel: CGColor { CGColor(srgbRed: 0.965, green: 0.96, blue: 0.945, alpha: 1) }
    static var rule: CGColor { CGColor(srgbRed: 0.85, green: 0.84, blue: 0.81, alpha: 1) }
    static var grid: CGColor { CGColor(srgbRed: 0.90, green: 0.90, blue: 0.88, alpha: 1) }
    static var curve: CGColor { CGColor(srgbRed: 0.55, green: 0.58, blue: 0.60, alpha: 1) }
    static var white: CGColor { CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1) }
}

private final class PDFLayout {
    enum Weight { case regular, bold }

    let report: GrowthReport
    let totalPages: Int
    let data = NSMutableData()
    var ctx: CGContext?
    var page = 0
    var y: CGFloat = 0

    let pageWidth: CGFloat = 612
    let pageHeight: CGFloat = 792
    let left: CGFloat = 54
    let right: CGFloat = 558
    let contentTop: CGFloat = 76
    let contentBottom: CGFloat = 736
    var width: CGFloat { right - left }

    init(report: GrowthReport, totalPages: Int) {
        self.report = report
        self.totalPages = totalPages
    }

    // MARK: Document

    func render() throws -> (data: Data, pages: Int) {
        var box = CGRect(origin: .zero, size: ReportPDFRenderer.pageSize)
        let info = [kCGPDFContextTitle as String: "\(report.title) – \(report.subjectName)",
                    kCGPDFContextCreator as String: BrandConfig.current.displayName] as CFDictionary
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &box, info) else {
            throw ReportPDFRenderer.RenderError.contextUnavailable
        }
        ctx = context
        drawCover()
        newPage()
        drawSections()
        endPage()
        context.closePDF()
        return (data as Data, page)
    }

    func newPage() {
        guard let ctx else { return }
        if page > 0 { endPage() }
        ctx.beginPDFPage(nil)
        page += 1
        ctx.saveGState()
        // Work in top-left coordinates (y grows downwards) like the app's layout.
        ctx.translateBy(x: 0, y: pageHeight)
        ctx.scaleBy(x: 1, y: -1)
        if page > 1 { drawHeader() }
        y = contentTop
    }

    func endPage() {
        guard let ctx else { return }
        drawFooter()
        ctx.restoreGState()
        ctx.endPDFPage()
    }

    func ensureSpace(_ height: CGFloat) {
        if y + height > contentBottom { newPage() }
    }

    // MARK: Text

    func font(_ size: CGFloat, _ weight: Weight) -> CTFont {
        let type: CTFontUIFontType = weight == .bold ? .emphasizedSystem : .system
        return CTFontCreateUIFontForLanguage(type, size, nil) ?? CTFontCreateWithName((weight == .bold ? "Helvetica-Bold" : "Helvetica") as CFString, size, nil)
    }

    func text(_ string: String, size: CGFloat, weight: Weight = .regular, color: CGColor = Ink.primary,
              alignment: CTTextAlignment = .left, lineSpacing: CGFloat = 2, kern: CGFloat = 0) -> NSAttributedString {
        var align = alignment
        var spacing = lineSpacing
        let style: CTParagraphStyle = withUnsafePointer(to: &align) { alignPointer in
            withUnsafePointer(to: &spacing) { spacingPointer in
                let settings = [
                    CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: alignPointer),
                    CTParagraphStyleSetting(spec: .lineSpacingAdjustment, valueSize: MemoryLayout<CGFloat>.size, value: spacingPointer)
                ]
                return CTParagraphStyleCreate(settings, settings.count)
            }
        }
        var attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font(size, weight),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
            NSAttributedString.Key(kCTParagraphStyleAttributeName as String): style
        ]
        if kern != 0 { attributes[NSAttributedString.Key(kCTKernAttributeName as String)] = NSNumber(value: Double(kern)) }
        return NSAttributedString(string: string, attributes: attributes)
    }

    func measure(_ attributed: NSAttributedString, width: CGFloat) -> CGFloat {
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(location: 0, length: 0), nil,
                                                                CGSize(width: width, height: .greatestFiniteMagnitude), nil)
        return ceil(size.height) + 1
    }

    /// Draws text in a rect given in top-left coordinates.
    func draw(_ attributed: NSAttributedString, in rect: CGRect) {
        guard let ctx else { return }
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        ctx.saveGState()
        ctx.translateBy(x: rect.minX, y: rect.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.textMatrix = .identity
        let path = CGPath(rect: CGRect(x: 0, y: 0, width: rect.width, height: rect.height), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
        CTFrameDraw(frame, ctx)
        ctx.restoreGState()
    }

    /// Draws at (x, y) with the given width and returns the height used.
    @discardableResult
    func draw(_ attributed: NSAttributedString, x: CGFloat, y top: CGFloat, width w: CGFloat) -> CGFloat {
        let h = measure(attributed, width: w)
        draw(attributed, in: CGRect(x: x, y: top, width: w, height: h))
        return h
    }

    // MARK: Shapes

    func fill(_ rect: CGRect, _ color: CGColor, radius: CGFloat = 0) {
        guard let ctx else { return }
        ctx.setFillColor(color)
        if radius > 0 {
            ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
            ctx.fillPath()
        } else {
            ctx.fill(rect)
        }
    }

    func line(from a: CGPoint, to b: CGPoint, _ color: CGColor, width w: CGFloat = 0.75, dash: [CGFloat] = []) {
        guard let ctx else { return }
        ctx.saveGState()
        ctx.setStrokeColor(color)
        ctx.setLineWidth(w)
        if !dash.isEmpty { ctx.setLineDash(phase: 0, lengths: dash) }
        ctx.move(to: a)
        ctx.addLine(to: b)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: Page furniture

    func drawHeader() {
        let label = text("\(report.title) · \(report.subjectName)", size: 8.5, color: Ink.secondary)
        draw(label, x: left, y: 38, width: width * 0.65)
        let date = text("Report date \(report.reportDateText)", size: 8.5, color: Ink.secondary, alignment: .right)
        draw(date, x: left + width * 0.5, y: 38, width: width * 0.5)
        line(from: CGPoint(x: left, y: 56), to: CGPoint(x: right, y: 56), Ink.rule)
    }

    func drawFooter() {
        line(from: CGPoint(x: left, y: 752), to: CGPoint(x: right, y: 752), Ink.rule)
        draw(text("Not a diagnosis. For discussion with a qualified healthcare professional.", size: 8, color: Ink.tertiary),
             x: left, y: 758, width: width * 0.72)
        let pageText = totalPages > 0 ? "Page \(page) of \(totalPages)" : "Page \(page)"
        draw(text(pageText, size: 8, color: Ink.tertiary, alignment: .right), x: left + width * 0.6, y: 758, width: width * 0.4)
    }

    // MARK: Cover

    func drawCover() {
        newPage()
        fill(CGRect(x: 0, y: 0, width: pageWidth, height: 8), Ink.accent)
        y = 64
        y += draw(text(BrandConfig.current.displayName.uppercased() + "  ·  GROWTH RECORD", size: 8.5, weight: .bold, color: Ink.accent, kern: 1.4),
                  x: left, y: y, width: width) + 8
        y += draw(text(report.title, size: 30, weight: .bold), x: left, y: y, width: width) + 2
        y += draw(text(report.subjectName, size: 15, color: Ink.secondary), x: left, y: y, width: width) + 18

        // Profile details grid
        let columns = 2
        let cellWidth = (width - 32) / CGFloat(columns)
        var rowHeights: [CGFloat] = []
        let fields = report.cover
        for row in stride(from: 0, to: fields.count, by: columns) {
            var h: CGFloat = 0
            for f in fields[row..<min(row + columns, fields.count)] {
                h = max(h, measure(text(f.label.uppercased(), size: 7.5, weight: .bold, kern: 0.6), width: cellWidth)
                        + measure(text(f.value, size: 11), width: cellWidth) + 2)
            }
            rowHeights.append(h + 10)
        }
        let gridHeight = rowHeights.reduce(0, +) + 18
        fill(CGRect(x: left, y: y, width: width, height: gridHeight), Ink.panel, radius: 10)
        var rowY = y + 12
        for (index, row) in stride(from: 0, to: fields.count, by: columns).enumerated() {
            for (col, f) in fields[row..<min(row + columns, fields.count)].enumerated() {
                let x = left + 16 + CGFloat(col) * cellWidth
                let lh = draw(text(f.label.uppercased(), size: 7.5, weight: .bold, color: Ink.tertiary, kern: 0.6), x: x, y: rowY, width: cellWidth - 8)
                draw(text(f.value, size: 11), x: x, y: rowY + lh + 1, width: cellWidth - 8)
            }
            rowY += rowHeights[index]
        }
        y += gridHeight + 18

        // At a glance
        y += draw(text("At a glance", size: 12, weight: .bold), x: left, y: y, width: width) + 6
        let glance = report.current.filter { ["Height", "Measured on", "Percentile"].contains($0.label) }
        let glanceWidth = width / CGFloat(max(glance.count, 1))
        var glanceHeight: CGFloat = 0
        for (i, f) in glance.enumerated() {
            let x = left + CGFloat(i) * glanceWidth
            let lh = draw(text(f.label, size: 8.5, color: Ink.tertiary), x: x, y: y, width: glanceWidth - 12)
            let vh = draw(text(f.value, size: 13, weight: .bold), x: x, y: y + lh, width: glanceWidth - 12)
            glanceHeight = max(glanceHeight, lh + vh)
        }
        if glance.isEmpty { glanceHeight = draw(text("No measurement recorded yet.", size: 10.5, color: Ink.secondary), x: left, y: y, width: width) }
        y += glanceHeight + 8
        y += draw(text(report.percentileSummary, size: 10.5, color: Ink.secondary, lineSpacing: 3), x: left, y: y, width: width) + 18

        // Please read
        let statements = report.disclaimer.map { "•  " + $0 }.joined(separator: "\n")
        let body = text(statements, size: 10, lineSpacing: 4)
        let boxHeight = measure(body, width: width - 40) + 40
        fill(CGRect(x: left, y: y, width: width, height: boxHeight), Ink.accentSoft, radius: 10)
        fill(CGRect(x: left, y: y, width: 4, height: boxHeight), Ink.accent)
        draw(text("Please read", size: 10, weight: .bold, color: Ink.accent), x: left + 20, y: y + 12, width: width - 40)
        draw(body, x: left + 20, y: y + 30, width: width - 40)
        y += boxHeight + 20

        // Contents
        y += draw(text("Contents", size: 12, weight: .bold), x: left, y: y, width: width) + 6
        for section in report.sections {
            var note = ""
            if case .limited(let reason) = section.status { note = reason }
            let titleText = text("\(section.number)   \(section.title)", size: 10)
            let h = measure(titleText, width: width * 0.6)
            ensureSpace(h + 4)
            draw(titleText, x: left, y: y, width: width * 0.6)
            if !note.isEmpty { draw(text(note, size: 9, color: Ink.tertiary, alignment: .right), x: left + width * 0.55, y: y + 1, width: width * 0.45) }
            y += h + 4
            line(from: CGPoint(x: left, y: y), to: CGPoint(x: right, y: y), Ink.grid, width: 0.5)
            y += 4
        }
    }

    // MARK: Sections

    func drawSections() {
        sectionHeading(1, "Current measurement")
        if report.current.isEmpty { paragraph("No measurement recorded.") } else { fields(report.current) }

        sectionHeading(2, "Growth chart", reserve: 360)
        if let chart = report.chart {
            drawChart(chart)
        } else {
            paragraph("Not included: there are no measurements within the chart's ages 2–20.")
        }

        sectionHeading(3, "Measurement history")
        table(report.measurements, widths: [0.27, 0.16, 0.37, 0.20], empty: "No measurements recorded.")

        sectionHeading(4, "Percentile history")
        paragraph(report.percentileSummary)
        table(report.percentileHistory, widths: [0.22, 0.13, 0.33, 0.19, 0.13], empty: "No measurements within the chart's age range.")

        sectionHeading(5, "Growth velocity")
        report.velocity.forEach { paragraph($0) }
        if !report.velocityTable.isEmpty {
            table(report.velocityTable, widths: [0.27, 0.27, 0.22, 0.24], empty: "")
        }

        sectionHeading(6, "Family-height context")
        report.family.forEach { paragraph($0) }

        sectionHeading(7, "Adult-height scenario")
        report.scenario.forEach { paragraph($0) }

        sectionHeading(8, "Methodology")
        bullets(report.methodology)

        sectionHeading(9, "Limitations")
        bullets(report.limitations)

        sectionHeading(10, "Questions to discuss with a healthcare professional")
        bullets(report.questions, numbered: true)
        y += 10
        ensureSpace(40)
        paragraph("Generated on \(report.reportDateText) from measurements entered in \(BrandConfig.current.displayName). Calculated on the device.", size: 8.5, color: Ink.tertiary)
    }

    func sectionHeading(_ number: Int, _ title: String, reserve: CGFloat = 90) {
        if y > contentTop { y += 14 }
        ensureSpace(reserve)
        let numberText = text(String(format: "%02d", number), size: 10, weight: .bold, color: Ink.accent, kern: 0.5)
        draw(numberText, x: left, y: y + 3, width: 28)
        let h = draw(text(title, size: 15, weight: .bold), x: left + 28, y: y, width: width - 28)
        y += h + 6
        line(from: CGPoint(x: left, y: y), to: CGPoint(x: right, y: y), Ink.rule)
        y += 10
    }

    func paragraph(_ string: String, size: CGFloat = 10.5, color: CGColor = Ink.primary) {
        let t = text(string, size: size, color: color, lineSpacing: 3)
        let h = measure(t, width: width)
        ensureSpace(h)
        draw(t, in: CGRect(x: left, y: y, width: width, height: h))
        y += h + 7
    }

    func bullets(_ items: [String], numbered: Bool = false) {
        for (i, item) in items.enumerated() {
            let t = text(item, size: 10.5, lineSpacing: 3)
            let h = measure(t, width: width - 22)
            ensureSpace(h + 4)
            draw(text(numbered ? "\(i + 1)." : "•", size: 10.5, weight: numbered ? .bold : .regular, color: Ink.accent), x: left, y: y, width: 20)
            draw(t, in: CGRect(x: left + 22, y: y, width: width - 22, height: h))
            y += h + 6
        }
    }

    func fields(_ items: [GrowthReport.Field]) {
        for f in items {
            let label = text(f.label, size: 10, color: Ink.secondary)
            let value = text(f.value, size: 10.5, weight: .bold)
            let h = max(measure(label, width: 170), measure(value, width: width - 180)) + 6
            ensureSpace(h)
            draw(label, x: left, y: y + 3, width: 170)
            draw(value, x: left + 180, y: y + 3, width: width - 180)
            y += h
            line(from: CGPoint(x: left, y: y), to: CGPoint(x: right, y: y), Ink.grid, width: 0.5)
        }
        y += 8
    }

    func table(_ table: GrowthReport.Table, widths: [CGFloat], empty: String) {
        guard !table.rows.isEmpty else {
            if !empty.isEmpty { paragraph(empty, color: Ink.secondary) }
            return
        }
        let columnWidths = widths.map { $0 * width }
        func rowHeight(_ cells: [String], bold: Bool) -> CGFloat {
            zip(cells, columnWidths).map { measure(text($0, size: 9.5, weight: bold ? .bold : .regular), width: $1 - 12) }.max().map { $0 + 9 } ?? 18
        }
        func drawRow(_ cells: [String], bold: Bool, fillColor: CGColor?) {
            let h = rowHeight(cells, bold: bold)
            if let fillColor { fill(CGRect(x: left, y: y, width: width, height: h), fillColor) }
            var x = left
            for (cell, w) in zip(cells, columnWidths) {
                draw(text(cell, size: 9.5, weight: bold ? .bold : .regular, color: bold ? Ink.secondary : Ink.primary), x: x + 6, y: y + 4.5, width: w - 12)
                x += w
            }
            y += h
        }
        let headerHeight = rowHeight(table.columns, bold: true)
        ensureSpace(headerHeight + rowHeight(table.rows[0], bold: false))
        drawRow(table.columns, bold: true, fillColor: Ink.panel)
        for (i, row) in table.rows.enumerated() {
            let h = rowHeight(row, bold: false)
            if y + h > contentBottom {
                newPage()
                drawRow(table.columns, bold: true, fillColor: Ink.panel)
            }
            drawRow(row, bold: false, fillColor: nil)
            if i < table.rows.count - 1 { line(from: CGPoint(x: left, y: y), to: CGPoint(x: right, y: y), Ink.grid, width: 0.5) }
        }
        line(from: CGPoint(x: left, y: y), to: CGPoint(x: right, y: y), Ink.rule)
        y += 12
    }

    // MARK: Chart

    func drawChart(_ chart: GrowthReport.Chart) {
        guard let ctx else { return }
        let boxHeight: CGFloat = 330
        ensureSpace(boxHeight + 50)
        y += draw(text(chart.title, size: 9.5, color: Ink.secondary), x: left, y: y, width: width) + 6
        let plot = CGRect(x: left + 38, y: y + 8, width: width - 38 - 34, height: boxHeight - 46)
        let ageSpan = chart.ageRange.upperBound - chart.ageRange.lowerBound
        let valueSpan = chart.valueRange.upperBound - chart.valueRange.lowerBound
        func point(_ age: Double, _ value: Double) -> CGPoint {
            CGPoint(x: plot.minX + CGFloat((age - chart.ageRange.lowerBound) / ageSpan) * plot.width,
                    y: plot.maxY - CGFloat((value - chart.valueRange.lowerBound) / valueSpan) * plot.height)
        }

        // Grid + axis labels
        let valueStep: Double = chart.unitLabel == "cm" ? 10 : 4
        var v = chart.valueRange.lowerBound
        while v <= chart.valueRange.upperBound + 0.001 {
            let p = point(chart.ageRange.lowerBound, v)
            line(from: CGPoint(x: plot.minX, y: p.y), to: CGPoint(x: plot.maxX, y: p.y), Ink.grid, width: 0.5)
            draw(text(String(Int(v)), size: 8, color: Ink.tertiary, alignment: .right), x: left, y: p.y - 5, width: 32)
            v += valueStep
        }
        let ageStep: Double = ageSpan > 10 ? 2 : 1
        var a = chart.ageRange.lowerBound.rounded(.up)
        while a <= chart.ageRange.upperBound + 0.001 {
            let p = point(a, chart.valueRange.lowerBound)
            line(from: CGPoint(x: p.x, y: plot.minY), to: CGPoint(x: p.x, y: plot.maxY), Ink.grid, width: 0.5)
            draw(text(String(Int(a)), size: 8, color: Ink.tertiary, alignment: .center), x: p.x - 12, y: plot.maxY + 4, width: 24)
            a += ageStep
        }
        draw(text("Age (years)", size: 8, color: Ink.secondary, alignment: .center), x: plot.minX, y: plot.maxY + 16, width: plot.width)
        draw(text(chart.unitLabel, size: 8, color: Ink.secondary, alignment: .right), x: left, y: plot.minY - 14, width: 32)

        // 25th–75th band
        if let p25 = chart.curves.first(where: { $0.percentile == 25 }), let p75 = chart.curves.first(where: { $0.percentile == 75 }), !p25.points.isEmpty {
            let path = CGMutablePath()
            path.move(to: point(p75.points[0].ageYears, p75.points[0].value))
            p75.points.dropFirst().forEach { path.addLine(to: point($0.ageYears, $0.value)) }
            p25.points.reversed().forEach { path.addLine(to: point($0.ageYears, $0.value)) }
            path.closeSubpath()
            ctx.saveGState()
            ctx.addRect(plot)
            ctx.clip()
            ctx.setFillColor(Ink.accentSoft)
            ctx.addPath(path)
            ctx.fillPath()
            ctx.restoreGState()
        }

        // Percentile curves
        for curve in chart.curves where !curve.points.isEmpty {
            let path = CGMutablePath()
            path.move(to: point(curve.points[0].ageYears, curve.points[0].value))
            curve.points.dropFirst().forEach { path.addLine(to: point($0.ageYears, $0.value)) }
            ctx.saveGState()
            ctx.addRect(plot)
            ctx.clip()
            ctx.setStrokeColor(Ink.curve)
            ctx.setLineWidth(curve.percentile == 50 ? 1.2 : 0.7)
            if curve.percentile == 3 || curve.percentile == 97 { ctx.setLineDash(phase: 0, lengths: [3, 2]) }
            ctx.addPath(path)
            ctx.strokePath()
            ctx.restoreGState()
            if let last = curve.points.last {
                let p = point(last.ageYears, last.value)
                if p.y > plot.minY - 4 && p.y < plot.maxY + 4 {
                    draw(text(PercentileFormatter.ordinalNumber(curve.percentile), size: 7.5, color: Ink.secondary), x: plot.maxX + 4, y: p.y - 5, width: 30)
                }
            }
        }

        // Measurements
        let points = chart.measurements.map { point($0.ageYears, $0.value) }
        if points.count > 1 {
            ctx.saveGState()
            ctx.setStrokeColor(Ink.accent)
            ctx.setLineWidth(1.6)
            ctx.setLineJoin(.round)
            ctx.move(to: points[0])
            points.dropFirst().forEach { ctx.addLine(to: $0) }
            ctx.strokePath()
            ctx.restoreGState()
        }
        for (i, p) in points.enumerated() {
            let r: CGFloat = 3.4
            let rect = CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)
            ctx.setFillColor(chart.estimated[i] ? Ink.white : Ink.accent)
            ctx.fillEllipse(in: rect)
            ctx.setStrokeColor(Ink.accent)
            ctx.setLineWidth(1.2)
            ctx.strokeEllipse(in: rect)
        }

        // Frame
        ctx.setStrokeColor(Ink.rule)
        ctx.setLineWidth(0.75)
        ctx.stroke(plot)

        y = plot.maxY + 32
        // Legend
        let legendY = y
        ctx.setFillColor(Ink.accent)
        ctx.fillEllipse(in: CGRect(x: left, y: legendY + 2, width: 7, height: 7))
        draw(text("Measurement", size: 8.5, color: Ink.secondary), x: left + 12, y: legendY, width: 90)
        ctx.setFillColor(Ink.white)
        ctx.fillEllipse(in: CGRect(x: left + 96, y: legendY + 2, width: 7, height: 7))
        ctx.setStrokeColor(Ink.accent)
        ctx.strokeEllipse(in: CGRect(x: left + 96, y: legendY + 2, width: 7, height: 7))
        draw(text("Estimated height", size: 8.5, color: Ink.secondary), x: left + 108, y: legendY, width: 100)
        fill(CGRect(x: left + 212, y: legendY + 1, width: 14, height: 9), Ink.accentSoft)
        draw(text("25th–75th percentile", size: 8.5, color: Ink.secondary), x: left + 231, y: legendY, width: 120)
        line(from: CGPoint(x: left + 352, y: legendY + 5.5), to: CGPoint(x: left + 366, y: legendY + 5.5), Ink.curve, width: 1.2)
        draw(text("Percentile lines 3–97", size: 8.5, color: Ink.secondary), x: left + 371, y: legendY, width: 140)
        y = legendY + 22
    }
}

#endif
