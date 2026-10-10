import Foundation

public struct AgentQuestionDigest: Sendable, Hashable, Identifiable {
    public enum Answer: Sendable, Hashable {
        case chosen([String])
        case typed(String)
        case hidden
        case unknown
    }

    public var answerID: String?
    public var header: String
    public var question: String
    public var answer: Answer

    public var id: String { answerID ?? question }

    public init(answerID: String?, header: String, question: String, answer: Answer) {
        self.answerID = answerID
        self.header = header
        self.question = question
        self.answer = answer
    }

    public static let hiddenText = "Hidden."

    public static func of(
        _ questions: [AgentQuestion], answers: [String: String]
    ) -> [AgentQuestionDigest] {
        questions.map { question in
            AgentQuestionDigest(
                answerID: question.answerID,
                header: question.header,
                question: question.question,
                answer: answer(to: question, text: answers[question.id] ?? "")
            )
        }
    }

    private static func answer(to question: AgentQuestion, text: String) -> Answer {
        let given = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !given.isEmpty else { return .unknown }
        guard !question.isSecret else { return .hidden }

        let labels = question.options.map(\.label)

        if labels.contains(given) { return .chosen([given]) }
        guard question.multiSelect,
              let picked = AgentQuestionnaire.split(given, into: labels)
        else {
            return .typed(given)
        }

        return .chosen(picked)
    }

    public var answerText: String {
        switch answer {
        case .chosen(let labels): AgentQuestionnaire.joined(labels)
        case .typed(let text): text
        case .hidden: Self.hiddenText
        case .unknown: ""
        }
    }

    public var isTyped: Bool {
        switch answer {
        case .typed, .hidden: true
        case .chosen, .unknown: false
        }
    }

    public var isAnswered: Bool {
        switch answer {
        case .chosen, .typed, .hidden: true
        case .unknown: false
        }
    }

    public var typed: String {
        guard case .typed(let text) = answer else { return "" }
        return text
    }

    public var chosen: Set<String> {
        guard case .chosen(let labels) = answer else { return [] }
        return Set(labels)
    }

    public var spoken: String {
        switch answer {
        case .chosen: "\(question) Answered: \(answerText)"
        case .typed: "\(question) Answered in your own words: \(answerText)"
        case .hidden: "\(question) Answered, and the answer is hidden."
        case .unknown: "\(question) The answer was not kept."
        }
    }
}
