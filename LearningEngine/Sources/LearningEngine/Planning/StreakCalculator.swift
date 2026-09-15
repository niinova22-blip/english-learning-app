import Foundation

public enum StreakCalculator {
    /// Consecutive local calendar days with activity, ending today — or
    /// ending yesterday if today has no activity yet (the streak only breaks
    /// once a whole day passes without activity).
    public static func streak(activityDates: [Date], now: Date, calendar: Calendar = .current) -> Int {
        let activeDays = Set(activityDates.map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: now)
        if !activeDays.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while activeDays.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}
