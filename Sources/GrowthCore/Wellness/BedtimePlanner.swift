import Foundation

/// Works back from a wake-up time to a bedtime, using the American Academy of Sleep Medicine's recommended
/// sleep for each age (consensus statement, 2016). Children and teens are given the middle of their range.
public enum BedtimePlanner {
    public struct Recommendation: Sendable, Equatable {
        /// Recommended range in hours, e.g. 8...10 for teens.
        public var rangeHours: ClosedRange<Double>
        /// The target used to plan, in minutes.
        public var targetMinutes: Int
        public var source: String
    }

    public struct Plan: Sendable, Equatable {
        public var wakeMinutes: Int
        public var bedtimeMinutes: Int
        public var windDownMinutes: Int
        public var targetSleepMinutes: Int

        /// When the wind-down reminder fires.
        public var windDownStartMinutes: Int { normalised(bedtimeMinutes - windDownMinutes) }
    }

    public static let source = "American Academy of Sleep Medicine, recommended sleep by age (2016)"

    public static func recommendation(ageYears: Int) -> Recommendation {
        switch ageYears {
        case ..<6: return Recommendation(rangeHours: 10...13, targetMinutes: 11 * 60 + 30, source: source)
        case 6...12: return Recommendation(rangeHours: 9...12, targetMinutes: 10 * 60, source: source)
        case 13...17: return Recommendation(rangeHours: 8...10, targetMinutes: 9 * 60, source: source)
        default: return Recommendation(rangeHours: 7...9, targetMinutes: 8 * 60, source: "American Academy of Sleep Medicine and Sleep Research Society (2015)")
        }
    }

    public static func plan(settings: BedtimeSettings, ageYears: Int) -> Plan {
        let target = settings.targetSleepMinutes ?? recommendation(ageYears: ageYears).targetMinutes
        // Allow about 15 minutes to fall asleep.
        let bedtime = normalised(settings.wakeMinutes - target - 15)
        return Plan(wakeMinutes: normalised(settings.wakeMinutes), bedtimeMinutes: bedtime, windDownMinutes: settings.windDownMinutes,
                    targetSleepMinutes: target)
    }

    /// "9:45 PM" in the given locale.
    public static func timeText(_ minutes: Int, locale: Locale = .current, calendar: Calendar = .current) -> String {
        var components = DateComponents()
        components.hour = normalised(minutes) / 60
        components.minute = normalised(minutes) % 60
        let date = calendar.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// "9 h 30 min" or "9 h".
    public static func durationText(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }
}

/// Keeps a minute-of-day value in 0..<1440.
func normalised(_ minutes: Int) -> Int {
    ((minutes % 1440) + 1440) % 1440
}
