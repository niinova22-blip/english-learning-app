import Foundation

public enum SampleContent {
    public static func ydsStarterPackage() -> ContentPackage {
        let package = ContentPackage(id: "sample-yds", name: "YDS Başlangıç", goal: .yds, levelLower: "B2", levelUpper: "C1")

        let businessUnit = Unit(id: "sample-unit-business", theme: "Business & Finance", order: 0)
        businessUnit.lessons = [
            makeLesson(id: "sample-lesson-business-1", order: 0, items: [
                item("serendipity", .vocabulary, frequencyRank: 4821, definition: "a pleasant surprise found by chance", examples: ["Meeting her was pure serendipity."], tr: "tesadüfi mutluluk", collocations: ["pure serendipity"]),
                item("leverage", .vocabulary, frequencyRank: 1890, definition: "use something to maximum advantage", examples: ["The company leveraged its brand to enter new markets."], tr: "kaldıraç etkisi kullanmak", collocations: ["leverage resources", "leverage a position"]),
                item("in the long run", .phrase, frequencyRank: 2200, definition: "over a long period of time, eventually", examples: ["It will save money in the long run."], tr: "uzun vadede", collocations: []),
                item("mitigate", .vocabulary, frequencyRank: 3100, definition: "make something less severe", examples: ["They took steps to mitigate the risk."], tr: "hafifletmek", collocations: ["mitigate risk", "mitigate damage"])
            ]),
            makeLesson(id: "sample-lesson-business-2", order: 1, items: [
                item("present perfect for unfinished actions", .grammarPoint, frequencyRank: 1, definition: "use 'have/has + past participle' for actions started in the past and continuing now", examples: ["She has worked here since 2019."], tr: "geçmişte başlayıp devam eden eylemler için present perfect", collocations: []),
                item("stakeholder", .vocabulary, frequencyRank: 2650, definition: "a person with an interest in a business", examples: ["All stakeholders were informed of the decision."], tr: "paydaş", collocations: ["key stakeholder"]),
                item("bear in mind", .phrase, frequencyRank: 3400, definition: "remember, take into consideration", examples: ["Bear in mind that prices may change."], tr: "aklında bulundurmak", collocations: []),
                item("streamline", .vocabulary, frequencyRank: 3900, definition: "make a process more efficient", examples: ["The new software streamlined our workflow."], tr: "kolaylaştırmak", collocations: ["streamline a process"]),
                item("make a decision", .collocation, frequencyRank: 500, definition: "decide", examples: ["The board will make a decision next week."], tr: "karar vermek", collocations: ["make a quick decision"])
            ])
        ]

        let scienceUnit = Unit(id: "sample-unit-science", theme: "Science & Technology", order: 1)
        scienceUnit.lessons = [
            makeLesson(id: "sample-lesson-science-1", order: 0, items: [
                item("unprecedented", .vocabulary, frequencyRank: 4300, definition: "never having happened before", examples: ["The research showed unprecedented results."], tr: "eşi görülmemiş", collocations: ["unprecedented growth"]),
                item("albeit", .vocabulary, frequencyRank: 3700, definition: "although", examples: ["The plan worked, albeit slowly."], tr: "gerçi, her ne kadar", collocations: []),
                item("hypothesis", .vocabulary, frequencyRank: 2900, definition: "a proposed explanation to be tested", examples: ["The hypothesis was confirmed by the experiment."], tr: "hipotez", collocations: ["test a hypothesis"]),
                item("passive voice in academic writing", .grammarPoint, frequencyRank: 2, definition: "using 'be + past participle' to focus on the action, common in academic texts", examples: ["The data were collected over six months."], tr: "akademik yazımda edilgen çatı", collocations: [])
            ]),
            makeLesson(id: "sample-lesson-science-2", order: 1, items: [
                item("ubiquitous", .vocabulary, frequencyRank: 4600, definition: "present everywhere", examples: ["Smartphones have become ubiquitous."], tr: "her yerde bulunan", collocations: []),
                item("counterintuitive", .vocabulary, frequencyRank: 4950, definition: "opposite to what you would expect", examples: ["The result was counterintuitive."], tr: "sezgiye aykırı", collocations: []),
                item("draw a conclusion", .collocation, frequencyRank: 1200, definition: "reach a judgment after considering facts", examples: ["It's too early to draw a conclusion."], tr: "sonuca varmak", collocations: []),
                item("shed light on", .phrase, frequencyRank: 2800, definition: "help explain something", examples: ["The study sheds light on climate patterns."], tr: "aydınlatmak, açıklık getirmek", collocations: []),
                item("empirical evidence", .collocation, frequencyRank: 3300, definition: "evidence based on observation or experiment", examples: ["The claim lacks empirical evidence."], tr: "ampirik kanıt", collocations: [])
            ])
        ]

        package.units = [businessUnit, scienceUnit]
        return package
    }

    private static func makeLesson(id: String, order: Int, items: [LearningItem]) -> Lesson {
        let lesson = Lesson(id: id, order: order, estimatedDurationMinutes: 4)
        lesson.items = items
        for item in items { item.lesson = lesson }
        return lesson
    }

    private static func item(_ headword: String, _ type: LearningItemType, frequencyRank: Int, definition: String, examples: [String], tr: String, collocations: [String]) -> LearningItem {
        let id = "sample-item-\(headword.lowercased().replacingOccurrences(of: " ", with: "-"))"
        let learningItem = LearningItem(id: id, type: type, frequencyRank: frequencyRank, baseDifficulty: Double(frequencyRank) / 5000.0)
        let content = ItemContent(id: "\(id)-content", headword: headword, definition: definition, exampleSentences: examples, translationTR: tr, collocations: collocations)
        learningItem.content = content
        content.item = learningItem
        return learningItem
    }
}
