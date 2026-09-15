import Foundation

/// Two units (order 0 and 1), two vocabulary lessons each (8 minutes), two
/// items per lesson. Item IDs: "<prefix>-u<unit>-l<lesson>-i<item>".
enum TestPackageJSON {
    static func make(id: String = "pkg", version: Int = 1, titleSuffix: String = "", prefix: String = "item") -> Data {
        func item(_ u: Int, _ l: Int, _ i: Int) -> String {
            """
            { "id": "\(prefix)-u\(u)-l\(l)-i\(i)", "type": "vocabulary", "headword": "word\(u)\(l)\(i)",
              "frequencyRank": \(u * 10 + l + i), "baseDifficulty": 0.3,
              "definition": "d", "exampleSentences": ["e"], "translationTR": "t", "collocations": [] }
            """
        }
        func lesson(_ u: Int, _ l: Int) -> String {
            """
            { "id": "lesson-u\(u)-l\(l)", "order": \(l), "estimatedDurationMinutes": 8,
              "title": "Unit \(u) · \(l + 1)\(titleSuffix)", "skill": "vocabulary",
              "items": [\(item(u, l, 0)), \(item(u, l, 1))] }
            """
        }
        func unit(_ u: Int) -> String {
            """
            { "id": "unit-\(u)", "theme": "Unit \(u)", "order": \(u), "lessons": [\(lesson(u, 0)), \(lesson(u, 1))] }
            """
        }
        return """
        { "id": "\(id)", "name": "Test \(id)", "goal": "yds", "levelLower": "B2", "levelUpper": "C1",
          "version": \(version),
          "skillWeights": { "vocabulary": 35, "grammar": 30, "reading": 35, "listening": 0, "writing": 0, "speaking": 0, "pronunciation": 0 },
          "units": [\(unit(0)), \(unit(1))] }
        """.data(using: .utf8)!
    }

    static let invalid = #"{ "id": "pkg", "name": "x", "goal": "yds", "levelLower": "B2", "levelUpper": "C1", "version": 9, "skillWeights": {}, "units": [] }"#.data(using: .utf8)!
}
