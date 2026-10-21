import Foundation
import GrowthEngine

/// "When will these stop fitting?" Projects height a few months ahead by following the current percentile line
/// of the growth chart, then maps it to approximate US children's clothing sizes.
///
/// The projection is a planning aid for shopping, never a prediction shown as fact: it assumes the child keeps
/// growing along the same percentile, which is what most children do over a few months.
public struct OutgrowForecast: Sendable, Equatable {
    public struct Point: Sendable, Equatable, Identifiable {
        public var months: Int
        public var date: Date
        public var heightCm: Double
        public var gainCm: Double
        public var clothingSize: String
        public var id: Int { months }
    }

    public var currentHeightCm: Double
    public var currentSize: String
    public var points: [Point]
    /// First horizon at which the clothing size changes, if any.
    public var nextSizeChange: Point? { points.first { $0.clothingSize != currentSize } }
    /// How often to check shoe fit at this age, in months.
    public var shoeCheckMonths: Int?

    public static let horizons = [3, 6, 12]

    public static func make(profile: GrowthProfile, analysis: GrowthAnalysis, now: Date, calendar: Calendar,
                            reference: GrowthReference = ReferenceRegistry.cdc2000) -> OutgrowForecast? {
        guard let latest = analysis.latest, let z = latest.percentile?.z else { return nil }
        let sex = profile.chartSex.referenceSex
        guard let adultAge = reference.adultAgeMonths(for: .stature, sex: sex),
              let baseline = PercentileCalculator.height(atZ: z, ageMonths: latest.ageMonths, sex: sex, reference: reference) else { return nil }
        let nowMonths = AgeMath.exactAgeMonths(birthDate: profile.birthDate, on: now, calendar: calendar)
        guard nowMonths < adultAge - 1 else { return nil }

        func projected(atAgeMonths age: Double) -> Double {
            let clamped = min(age, adultAge)
            let curve = PercentileCalculator.height(atZ: z, ageMonths: clamped, sex: sex, reference: reference) ?? baseline
            return latest.heightCm + max(0, curve - baseline)
        }

        let current = projected(atAgeMonths: nowMonths)
        let points = horizons.compactMap { months -> Point? in
            guard let date = calendar.date(byAdding: .month, value: months, to: now) else { return nil }
            let height = projected(atAgeMonths: nowMonths + Double(months))
            return Point(months: months, date: date, heightCm: height, gainCm: height - current, clothingSize: ClothingSize.label(forHeightCm: height))
        }
        let years = Int(nowMonths / 12)
        return OutgrowForecast(currentHeightCm: current, currentSize: ClothingSize.label(forHeightCm: current), points: points,
                               shoeCheckMonths: shoeCheckMonths(ageYears: years))
    }

    /// Common foot-care advice: children's feet grow fastest when young, so check shoe fit more often.
    static func shoeCheckMonths(ageYears: Int) -> Int? {
        switch ageYears {
        case ..<3: return 2
        case 3...5: return 3
        case 6...11: return 4
        case 12...15: return 6
        default: return nil
        }
    }
}

/// Approximate US children's clothing sizes by height. Brands differ, so the app always says "about".
public enum ClothingSize {
    /// Upper height bound (cm) for each size label.
    static let table: [(maxCm: Double, label: String)] = [
        (91, "2T"), (99, "3T"), (106, "4"), (114, "5"), (122, "6"), (128, "7"), (135, "8"),
        (142, "10"), (150, "12"), (158, "14"), (166, "16")
    ]

    public static func label(forHeightCm height: Double) -> String {
        table.first { height <= $0.maxCm }?.label ?? "Adult sizes"
    }
}
