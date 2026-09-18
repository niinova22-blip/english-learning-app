import XCTest
@testable import LearningEngine

final class SkillWeightsTests: XCTestCase {
    private func full(_ overrides: [Skill: Double] = [:]) -> [Skill: Double] {
        var values = Dictionary(uniqueKeysWithValues: Skill.allCases.map { ($0, 0.0) })
        values[.vocabulary] = 1
        for (k, v) in overrides { values[k] = v }
        return values
    }

    func test_skillOrder_isExactlyTheSevenSkills() {
        XCTAssertEqual(Skill.allCases.map(\.rawValue),
                       ["vocabulary", "grammar", "reading", "listening", "writing", "speaking", "pronunciation"])
    }

    func test_itemTypeMapping() {
        XCTAssertEqual(Skill.forItemType(.vocabulary), .vocabulary)
        XCTAssertEqual(Skill.forItemType(.phrase), .vocabulary)
        XCTAssertEqual(Skill.forItemType(.collocation), .vocabulary)
        XCTAssertEqual(Skill.forItemType(.grammarPoint), .grammar)
    }

    func test_shares_areNormalized_andActiveSkillsExcludeZero() throws {
        let weights = try SkillWeights(full([.vocabulary: 35, .grammar: 30, .reading: 35]))
        XCTAssertEqual(weights.share(of: .vocabulary), 0.35, accuracy: 1e-9)
        XCTAssertEqual(weights.share(of: .grammar), 0.30, accuracy: 1e-9)
        XCTAssertEqual(weights.share(of: .pronunciation), 0, accuracy: 1e-9)
        XCTAssertEqual(weights.activeSkills, [.vocabulary, .grammar, .reading])
    }

    func test_init_missingSkill_throws() {
        var values = full()
        values.removeValue(forKey: .speaking)
        XCTAssertThrowsError(try SkillWeights(values)) { error in
            XCTAssertEqual(error as? SkillWeightsError, .missingSkill(.speaking))
        }
    }

    func test_init_negativeWeight_throws() {
        XCTAssertThrowsError(try SkillWeights(full([.grammar: -1]))) { error in
            XCTAssertEqual(error as? SkillWeightsError, .negativeWeight(.grammar))
        }
    }

    func test_init_allZero_throws() {
        XCTAssertThrowsError(try SkillWeights(full([.vocabulary: 0]))) { error in
            XCTAssertEqual(error as? SkillWeightsError, .zeroTotal)
        }
    }

    func test_vocabularyOnly_isOnlyVocabulary() {
        XCTAssertEqual(SkillWeights.vocabularyOnly.activeSkills, [.vocabulary])
    }
}
