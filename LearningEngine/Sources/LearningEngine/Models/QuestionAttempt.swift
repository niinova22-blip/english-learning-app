import Foundation
import SwiftData

/// One answered question. Written immediately on every answer (not only on
/// session completion), so a quit-midway session still informs later
/// question selection. Deliberately has no unique id: a learner answers the
/// same question many times across reviews.
@Model
public final class QuestionAttempt {
    public var userID: String = ""
    public var questionID: String = ""
    public var wasCorrect: Bool = false
    public var answeredAt: Date = Date(timeIntervalSince1970: 0)
    public var selectedIndex: Int = 0

    public init(userID: String, questionID: String, wasCorrect: Bool, answeredAt: Date, selectedIndex: Int) {
        self.userID = userID
        self.questionID = questionID
        self.wasCorrect = wasCorrect
        self.answeredAt = answeredAt
        self.selectedIndex = selectedIndex
    }
}
