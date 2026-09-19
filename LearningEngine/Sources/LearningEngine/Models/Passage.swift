import Foundation
import SwiftData

/// A reading or cloze text. Owned by exactly one lesson; its questions point
/// back at it so the screen can keep the text pinned above the question.
@Model
public final class Passage {
    @Attribute(.unique) public var id: String
    public var title: String = ""
    public var body: String = ""
    public var lesson: Lesson?
    @Relationship(deleteRule: .nullify, inverse: \Question.passage)
    public var questions: [Question] = []

    public init(id: String, title: String, body: String) {
        self.id = id
        self.title = title
        self.body = body
    }
}
