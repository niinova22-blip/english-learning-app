import Foundation

/// One unit, one lesson, 15 vocabulary items with varied baseDifficulty
/// (0.15...0.6) — enough for LevelTestEngine.questionCount (12) to run for
/// real, unlike TestPackageJSON's 8 items.
enum RichLevelTestPackageJSON {
    static func make(id: String = "pkg") -> Data {
        let items = (0..<15).map { i -> String in
            let difficulty = 0.15 + Double(i) * (0.45 / 14.0)
            return """
            { "id": "rich-item-\(i)", "type": "vocabulary", "headword": "word\(i)",
              "frequencyRank": \(i), "baseDifficulty": \(difficulty),
              "definition": "d", "exampleSentences": ["e"], "translationTR": "anlam\(i)", "collocations": [] }
            """
        }.joined(separator: ",")
        return """
        { "id": "\(id)", "name": "Rich \(id)", "goal": "yds", "levelLower": "B2", "levelUpper": "C1",
          "version": 1,
          "skillWeights": { "vocabulary": 35, "grammar": 30, "reading": 35, "listening": 0, "writing": 0, "speaking": 0, "pronunciation": 0 },
          "units": [{ "id": "unit-0", "theme": "Unit 0", "order": 0, "lessons": [
            { "id": "lesson-0", "order": 0, "estimatedDurationMinutes": 20, "title": "Lesson 1", "skill": "vocabulary", "items": [\(items)] }
          ] }] }
        """.data(using: .utf8)!
    }
}
