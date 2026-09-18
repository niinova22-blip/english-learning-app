import Foundation

enum RatingIntervalFormatter {
    /// Calendar-day distance as Turkish text. The FSRS engine never schedules
    /// under a day, so the minimum shown is "1 gün".
    static func text(from now: Date, to due: Date, calendar: Calendar = .current) -> String {
        let days = max(calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: due)).day ?? 1, 1)
        if days < 30 { return "\(days) gün" }
        if days < 365 { return "\(days / 30) ay" }
        return "\(days / 365) yıl"
    }
}
