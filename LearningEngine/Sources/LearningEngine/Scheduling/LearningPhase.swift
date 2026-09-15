public enum LearningPhase: Sendable, Equatable {
    case blocked(dominantTopic: LearningItemType)
    case hybrid(primaryWeakTopic: LearningItemType)
    case fullInterleaving
}
