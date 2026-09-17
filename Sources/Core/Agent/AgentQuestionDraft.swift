import Foundation

public struct AgentQuestionDraft: Sendable, Hashable {
    public var chosen: [String: Set<String>] = [:]
    public var other: [String: String] = [:]
    public var isWritingOther: Set<String> = []

    public init() {}

    public mutating func toggle(_ label: String, on question: AgentQuestion) {
        isWritingOther.remove(question.id)
        other[question.id] = ""

        var set = chosen[question.id] ?? []

        if question.multiSelect {
            if set.contains(label) { set.remove(label) } else { set.insert(label) }
        } else {
            set = set.contains(label) ? [] : [label]
        }

        chosen[question.id] = set
    }

    public mutating func writeOther(on question: AgentQuestion) {
        isWritingOther.insert(question.id)
        chosen[question.id] = []
    }

    public func answers(to questions: [AgentQuestion]) -> [String: String] {
        var answers: [String: String] = [:]

        for question in questions {
            let typed = (other[question.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            if !typed.isEmpty {
                answers[question.id] = typed
                continue
            }

            let picked = question.options.map(\.label).filter { chosen[question.id]?.contains($0) ?? false }

            if !picked.isEmpty {
                answers[question.id] = AgentQuestionnaire.joined(picked)
            }
        }

        return answers
    }

    public func isComplete(_ questions: [AgentQuestion]) -> Bool {
        AgentQuestionnaire.isComplete(questions, answers: answers(to: questions))
    }
}
