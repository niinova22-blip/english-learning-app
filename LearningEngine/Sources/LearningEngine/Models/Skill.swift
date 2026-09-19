import Foundation

/// The shared skill set every goal package weights. Order matters: it is the
/// tie-break order and the display order.
public enum Skill: String, Codable, CaseIterable, Sendable {
    case vocabulary, grammar, reading, listening, writing, speaking, pronunciation

    /// Which skill a reviewed item counts toward.
    public static func forItemType(_ type: LearningItemType) -> Skill {
        switch type {
        case .vocabulary, .phrase, .collocation: return .vocabulary
        case .grammarPoint: return .grammar
        // A practice set has no intrinsic skill — the owning lesson decides.
        // This branch is only the last-resort fallback for an orphan item.
        case .practiceSet: return .reading
        }
    }

    /// Skill attribution for a reviewed item: the owning lesson's skill wins,
    /// so a reading practice set counts toward `reading` and a sentence-
    /// completion set toward `grammar`. `forItemType` remains the fallback
    /// for items with no lesson.
    public static func forItem(type: LearningItemType, lessonSkill: Skill?) -> Skill {
        lessonSkill ?? forItemType(type)
    }
}

public enum SkillWeightsError: Error, Equatable {
    case missingSkill(Skill)
    case negativeWeight(Skill)
    case zeroTotal
}

/// Per-package skill weights. Always contains all seven skills, each >= 0,
/// with a positive total.
public struct SkillWeights: Sendable, Equatable {
    private let values: [Skill: Double]

    public init(_ values: [Skill: Double]) throws {
        for skill in Skill.allCases {
            guard let value = values[skill] else { throw SkillWeightsError.missingSkill(skill) }
            guard value >= 0 else { throw SkillWeightsError.negativeWeight(skill) }
        }
        guard values.values.reduce(0, +) > 0 else { throw SkillWeightsError.zeroTotal }
        self.values = values
    }

    public static let vocabularyOnly: SkillWeights = {
        var values = Dictionary(uniqueKeysWithValues: Skill.allCases.map { ($0, 0.0) })
        values[.vocabulary] = 1
        return try! SkillWeights(values)
    }()

    public func weight(of skill: Skill) -> Double { values[skill] ?? 0 }

    public func share(of skill: Skill) -> Double {
        weight(of: skill) / values.values.reduce(0, +)
    }

    public var activeSkills: [Skill] { Skill.allCases.filter { weight(of: $0) > 0 } }
}
