import Foundation
import SwiftData

/// Created when a learner first enters a lesson; `completedAt` is set once
/// every item of the lesson has been rated at least once.
@Model
public final class LessonProgress {
    @Attribute(.unique) public var id: String
    public var userID: String
    public var lessonID: String
    public var startedAt: Date
    public var completedAt: Date?

    public init(userID: String, lessonID: String, startedAt: Date) {
        self.id = LessonProgress.makeID(userID: userID, lessonID: lessonID)
        self.userID = userID
        self.lessonID = lessonID
        self.startedAt = startedAt
        self.completedAt = nil
    }

    public static func makeID(userID: String, lessonID: String) -> String {
        "\(userID)|\(lessonID)"
    }
}
