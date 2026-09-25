import Foundation

enum RatingIntervalFormatter {
    /// Calendar-day distance as localized text (English "N days/months/years";
    /// Turkish devices see "gün/ay/yıl" via the catalog). The FSRS engine
    /// never schedules under a day, so the minimum shown is "1 day".
    static func text(from now: Date, to due: Date, calendar: Calendar = .current) -> String {
        let days = max(calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: due)).day ?? 1, 1)
        if days < 30 { return String(localized: "\(days) days") }
        if days < 365 { return String(localized: "\(days / 30) months") }
        return String(localized: "\(days / 365) years")
    }
}
