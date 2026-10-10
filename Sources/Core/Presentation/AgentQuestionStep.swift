import Foundation

public struct AgentQuestionStep: Sendable, Hashable {
    public private(set) var index: Int
    public private(set) var count: Int

    public init(count: Int, index: Int = 0) {
        self.count = max(0, count)
        self.index = Self.held(index, within: self.count)
    }

    public var isAlone: Bool { count <= 1 }

    public var isFirst: Bool { index <= 0 }

    public var isLast: Bool { index >= count - 1 }

    public var label: String { "\(index + 1) of \(count)" }

    @discardableResult
    public mutating func advance() -> Bool {
        go(to: index + 1)
    }

    @discardableResult
    public mutating func retreat() -> Bool {
        go(to: index - 1)
    }

    @discardableResult
    public mutating func go(to wanted: Int) -> Bool {
        let held = Self.held(wanted, within: count)
        guard held != index else { return false }
        index = held
        return true
    }

    public mutating func resize(to count: Int) {
        self.count = max(0, count)
        index = Self.held(index, within: self.count)
    }

    private static func held(_ wanted: Int, within count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(0, wanted), count - 1)
    }

    public static func opening(
        of questions: [AgentQuestion], answers: [String: String]
    ) -> AgentQuestionStep {
        AgentQuestionStep(count: questions.count, index: waiting(in: questions, answers: answers).first ?? 0)
    }

    public static func waiting(
        in questions: [AgentQuestion], answers: [String: String]
    ) -> [Int] {
        questions.indices.filter { index in
            let given = answers[questions[index].id] ?? ""
            return given.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    public static func stillToAnswer(
        _ questions: [AgentQuestion], answers: [String: String]
    ) -> String {
        let waiting = waiting(in: questions, answers: answers)

        guard let first = waiting.first else { return "" }
        guard waiting.count == 1 else {
            return "\(Counted.of(waiting.count, "question")) are still unanswered."
        }

        return "Question \(first + 1) is still unanswered."
    }
}
