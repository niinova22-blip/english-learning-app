import Foundation

/// The learner's daily-reminder choice, stored in UserDefaults. The keys are
/// public so SwiftUI views can bind them with @AppStorage.
final class ReminderSettings {
    static let enabledKey = "reminders.daily.enabled"
    static let hourKey = "reminders.daily.hour"
    static let minuteKey = "reminders.daily.minute"
    static let defaultHour = 20

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Self.enabledKey) }
        set { defaults.set(newValue, forKey: Self.enabledKey) }
    }

    var hour: Int {
        get { defaults.object(forKey: Self.hourKey) as? Int ?? Self.defaultHour }
        set { defaults.set(newValue, forKey: Self.hourKey) }
    }

    var minute: Int {
        get { defaults.object(forKey: Self.minuteKey) as? Int ?? 0 }
        set { defaults.set(newValue, forKey: Self.minuteKey) }
    }
}
