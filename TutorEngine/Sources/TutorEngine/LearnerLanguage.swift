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
