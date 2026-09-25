import Foundation

/// Which language the learner's interface is in, and therefore which
/// language the tutor, chat and coach prompts should be written in and
/// should ask the model to answer in. Defaults to `.turkish` in every
/// request initialiser so existing call sites and tests keep compiling;
/// the App always passes the real value from `AppLanguage`.
public enum LearnerLanguage: Sendable, Equatable {
    case turkish
    case english
}

/// The first line of the card and question prompts. A nil `goalDescription`
/// keeps the original wording (the YDS goal on Turkish UI); otherwise it
/// completes "... learner who is <goalDescription>." — for example
/// "improving their business English".
enum TutorOpening {
    static func line(for language: LearnerLanguage, goalDescription: String?) -> String {
        switch (language, goalDescription) {
        case (.turkish, nil):
            return "You are a concise, encouraging English tutor helping a Turkish-speaking learner preparing for the YDS exam."
        case (.turkish, let goal?):
            return "You are a concise, encouraging English tutor helping a Turkish-speaking learner who is \(goal)."
        case (.english, nil):
            return "You are a concise, encouraging English tutor helping an English learner."
        case (.english, let goal?):
            return "You are a concise, encouraging English tutor helping an English learner who is \(goal)."
        }
    }
}
