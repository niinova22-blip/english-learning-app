import Foundation

/// Turns a `QuestionTutorRequest` into the text prompt sent to the model.
/// Pure and deterministic, like `PromptBuilder` — all wording iteration
/// happens here, with no model-loading code involved.
public enum QuestionPromptBuilder {
    private static func letter(_ index: Int) -> String {
        let letters = ["A", "B", "C", "D", "E"]
        return index >= 0 && index < letters.count ? letters[index] : "\(index + 1)"
    }

    private static func labelled(_ options: [String], _ index: Int) -> String {
        guard index >= 0, index < options.count else { return "-" }
        return "\(letter(index))) \(options[index])"
    }

    private static func passageBlock(_ passage: String?) -> String {
        guard let passage, !passage.isEmpty else { return "" }
        return "Passage:\n---\n\(passage)\n---\n\n"
    }

    public static func build(for request: QuestionTutorRequest) -> String {
        let optionLines = request.options.indices
            .map { labelled(request.options, $0) }
            .joined(separator: "\n")

        var prompt = """
        You are a concise, encouraging English tutor helping a Turkish-speaking learner preparing for the YDS exam.
        The learner is working on this multiple-choice question:

        \(passageBlock(request.passage))Question: \(request.prompt)
        \(optionLines)

        Correct answer: \(labelled(request.options, request.correctIndex))

        """

        if let selectedIndex = request.selectedIndex {
            prompt += "The learner chose: \(labelled(request.options, selectedIndex))\n"
        } else {
            prompt += "The learner has not answered yet.\n"
        }

        prompt += """
        The explanation the app already showed (in Turkish): \(request.explanationTR)


        """

        switch request.ask {
        case .quickAction(.simplerExplanation):
            prompt += "Explain, in plain English and in 2-3 short sentences, why the correct answer is right. Do not contradict the explanation above."
        case .quickAction(.anotherExample):
            prompt += "Write one new example sentence that uses the same grammar point or vocabulary as the correct answer, then translate it into Turkish."
        case .quickAction(.compareToSimilarWords):
            if request.selectedIndex == request.correctIndex {
                prompt += "The learner answered correctly. Explain briefly why each of the other options is wrong or less suitable here. Keep it to one short sentence per option."
            } else {
                prompt += "Explain briefly why the option the learner chose is wrong and how it differs from the correct answer. Keep it to 2-3 short sentences."
            }
        case .freeText(let question):
            prompt += "The learner asks: \"\(question)\". Answer clearly and briefly, staying focused on this question and why its answer is what it is."
        }

        return prompt
    }
}
