import Foundation
import SwiftData

@Model
public final class ItemContent {
    @Attribute(.unique) public var id: String
    public var headword: String
    public var definition: String
    public var exampleSentences: [String]
    public var translationTR: String
    public var collocations: [String]
    public var videoURL: URL?
    public var audioURL: URL?
    public var imageURL: URL?
    /// Turkish topic explanation for a grammar topic card (rule, examples,
    /// common traps). Nil for vocabulary items.
    public var explanationTR: String? = nil
    public var item: LearningItem?

    public init(
        id: String,
        headword: String,
        definition: String,
        exampleSentences: [String],
        translationTR: String,
        collocations: [String],
        videoURL: URL? = nil,
        audioURL: URL? = nil,
        imageURL: URL? = nil,
        explanationTR: String? = nil
    ) {
        self.id = id
        self.headword = headword
        self.definition = definition
        self.exampleSentences = exampleSentences
        self.translationTR = translationTR
        self.collocations = collocations
        self.videoURL = videoURL
        self.audioURL = audioURL
        self.imageURL = imageURL
        self.explanationTR = explanationTR
    }
}
