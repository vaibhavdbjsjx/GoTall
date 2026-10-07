import Foundation

/// Parses what people type into height fields. Accepts "." or "," as the decimal separator
/// regardless of locale, because people paste values from records written in other formats.
public enum HeightInputParser {
    public static func number(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, cleaned.filter({ $0 == "." }).count <= 1,
              cleaned.allSatisfy({ $0.isNumber || $0 == "." }) else { return nil }
        return Double(cleaned)
    }

    /// Centimetres from a cm field.
    public static func centimeters(_ text: String) -> Double? {
        number(text).map(HeightConversion.rounded)
    }

    /// Centimetres from feet + inches fields. Empty inches means 0. Inches must be below 12.
    public static func centimeters(feet feetText: String, inches inchesText: String) -> Double? {
        guard let feetValue = number(feetText), feetValue == feetValue.rounded(.down) else { return nil }
        let inches = inchesText.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : number(inchesText)
        guard let inches, inches < 12 else { return nil }
        return HeightConversion.centimeters(feet: Int(feetValue), inches: inches)
    }

    /// Text to pre-fill fields from a stored value.
    public static func fieldText(centimeters: Double?) -> String {
        guard let centimeters else { return "" }
        return String(format: "%.1f", HeightConversion.rounded(centimeters))
    }

    public static func fieldText(feetInchesFrom centimeters: Double?) -> (feet: String, inches: String) {
        guard let centimeters else { return ("", "") }
        let value = HeightConversion.feetInches(fromCentimeters: centimeters)
        return (String(value.feet), HeightFormatter.inchString(value.inches))
    }
}
