import Foundation

/// Turns a `TutorRequest` into the actual text prompt sent to the
/// model. Pure and deterministic — all prompt-wording iteration
/// happens here, with no model-loading code involved.
public enum PromptBuilder {
    public static func build(for request: TutorRequest) -> String {
        var prompt = """
        You are a concise, encouraging English tutor helping a Turkish-speaking learner preparing for the YDS exam.
        The learner is currently studying this word:

        Word: \(request.headword)
        Definition: \(request.definition)
        Example sentences: \(request.exampleSentences.joined(separator: " / "))
        Turkish translation: \(request.translationTR)


        """

        switch request.ask {
        case .quickAction(.simplerExplanation):
            prompt += "Explain the word \"\(request.headword)\" in simpler, plainer English than the definition above. Keep it to 2-3 short sentences."
        case .quickAction(.anotherExample):
            prompt += "Write one new example sentence using \"\(request.headword)\" that is different from the ones above."
        case .quickAction(.compareToSimilarWords):
            prompt += "Briefly explain how \"\(request.headword)\" differs in meaning or usage from one or two words learners commonly confuse it with. Keep it to 2-3 short sentences."
        case .freeText(let question):
            prompt += "The learner asks: \"\(question)\". Answer clearly and briefly, staying focused on the word \"\(request.headword)\" and its usage."
        }

        return prompt
    }
}
