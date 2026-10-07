import Foundation

public enum DisplayFormat {
    /// "Today", "Yesterday", "5 days ago", "3 weeks ago", "4 months ago", "Over a year ago".
    public static func relative(_ date: Date, to now: Date, calendar: Calendar) -> String {
        let start = calendar.startOfDay(for: date)
        let end = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        switch days {
        case ..<0: return "Upcoming"
        case 0: return "Today"
        case 1: return "Yesterday"
        case 2...13: return "\(days) days ago"
        case 14...59: return "\(days / 7) weeks ago"
        case 60...364:
            let months = calendar.dateComponents([.month], from: start, to: end).month ?? days / 30
            return "\(max(months, 2)) months ago"
        default: return "Over a year ago"
        }
    }

    /// "8 h 30 min"
    public static func duration(minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
    }

    /// "9:30 PM" style, using the given locale.
    public static func time(_ time: TimeOfDay, calendar: Calendar, locale: Locale = .current) -> String {
        var components = DateComponents()
        components.hour = time.hour
        components.minute = time.minute
        let date = calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// "Mar 2025"
    public static func monthYear(_ date: Date, calendar: Calendar, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMM yyyy")
        return formatter.string(from: date)
    }

    /// "Mar 4, 2025"
    public static func day(_ date: Date, calendar: Calendar, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
