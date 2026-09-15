import Foundation
import SwiftData

@Model
public final class ReviewLog {
    @Attribute(.unique) public var id: String
    public var userID: String
    public var itemID: String
    public var rating: FSRSRating
    public var reviewedAt: Date
    public var reactionTimeMs: Int

    public init(id: String = UUID().uuidString, userID: String, itemID: String, rating: FSRSRating, reviewedAt: Date, reactionTimeMs: Int = 0) {
        self.id = id
        self.userID = userID
        self.itemID = itemID
        self.rating = rating
        self.reviewedAt = reviewedAt
        self.reactionTimeMs = reactionTimeMs
    }
}
