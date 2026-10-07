import Foundation

public enum HeightUnit: String, Codable, CaseIterable, Sendable {
    case centimeters
    case feetInches
}

public struct FeetInches: Equatable, Sendable {
    public var feet: Int
    public var inches: Double

    public init(feet: Int, inches: Double) {
        self.feet = feet
        self.inches = inches
    }
}

/// Height is always stored in centimetres (one decimal place). Units only affect display and input,
/// so switching units never changes a stored value.
public enum HeightConversion {
    public static let centimetersPerInch = 2.54

    /// Rounds to the 0.1 cm storage precision.
    public static func rounded(_ centimeters: Double) -> Double {
        (centimeters * 10).rounded() / 10
    }

    public static func centimeters(feet: Int, inches: Double) -> Double {
        rounded((Double(feet) * 12 + inches) * centimetersPerInch)
    }

    /// Converts for display, snapping inches to `inchStep` (default ½ inch).
    public static func feetInches(fromCentimeters centimeters: Double, inchStep: Double = 0.5) -> FeetInches {
        let totalInches = centimeters / centimetersPerInch
        let snapped = (totalInches / inchStep).rounded() * inchStep
        var feet = Int((snapped / 12).rounded(.down))
        var inches = snapped - Double(feet) * 12
        if inches >= 12 - 1e-9 {
            feet += 1
            inches = 0
        }
        if abs(inches) < 1e-9 { inches = 0 }
        return FeetInches(feet: feet, inches: inches)
    }
}

public enum HeightFormatter {
    /// Compact visual string, e.g. "152.4 cm" or "5 ft 0.5 in".
    public static func string(centimeters: Double, unit: HeightUnit) -> String {
        switch unit {
        case .centimeters:
            return String(format: "%.1f cm", HeightConversion.rounded(centimeters))
        case .feetInches:
            let value = HeightConversion.feetInches(fromCentimeters: centimeters)
            return "\(value.feet) ft \(inchString(value.inches)) in"
        }
    }

    /// Spoken string for VoiceOver, e.g. "152.4 centimetres" or "5 feet 0.5 inches".
    public static func accessibleString(centimeters: Double, unit: HeightUnit) -> String {
        switch unit {
        case .centimeters:
            return String(format: "%.1f centimetres", HeightConversion.rounded(centimeters))
        case .feetInches:
            let value = HeightConversion.feetInches(fromCentimeters: centimeters)
            let feetWord = value.feet == 1 ? "foot" : "feet"
            let inchWord = value.inches == 1 ? "inch" : "inches"
            return "\(value.feet) \(feetWord) \(inchString(value.inches)) \(inchWord)"
        }
    }

    /// Signed change, e.g. "+3.2 cm" or "+1.5 in".
    public static func changeString(centimeters delta: Double, unit: HeightUnit) -> String {
        let sign = delta >= 0 ? "+" : "−"
        switch unit {
        case .centimeters:
            return sign + String(format: "%.1f cm", abs(HeightConversion.rounded(delta)))
        case .feetInches:
            let inches = (abs(delta) / HeightConversion.centimetersPerInch * 2).rounded() / 2
            return sign + "\(inchString(inches)) in"
        }
    }

    /// Compact imperial for tight layouts and ranges: 5′ 4½″.
    public static func compactImperial(centimeters: Double) -> String {
        let value = HeightConversion.feetInches(fromCentimeters: centimeters)
        let whole = Int(value.inches.rounded(.down))
        let half = value.inches - Double(whole) >= 0.5 ? "½" : ""
        return "\(value.feet)′ \(whole)\(half)″"
    }

    static func inchString(_ inches: Double) -> String {
        inches.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(inches)) : String(format: "%.1f", inches)
    }
}
