import Foundation

public struct AgentQuestion: Sendable, Hashable, Identifiable {
    public struct Option: Sendable, Hashable, Identifiable {
        public var label: String
        public var description: String
        public var preview: String?

        public var id: String { label }

        public init(label: String, description: String = "", preview: String? = nil) {
            self.label = label
            self.description = description
            self.preview = preview
        }

        static func decode(_ json: JSONValue) -> Option? {
            guard let label = json["label"]?.stringValue, !label.isEmpty else { return nil }
            let preview = json["preview"]?.stringValue
            return Option(
                label: label,
                description: json["description"]?.stringValue ?? "",
                preview: (preview?.isEmpty ?? true) ? nil : preview
            )
        }
    }

    public var question: String
    public var header: String
    public var multiSelect: Bool
    public var options: [Option]
    public var answerID: String?
    public var allowsOther: Bool
    public var isSecret: Bool

    public var id: String { answerID ?? question }

    public init(
        question: String, header: String = "", multiSelect: Bool = false, options: [Option] = [],
        answerID: String? = nil, allowsOther: Bool = true, isSecret: Bool = false
    ) {
        self.question = question
        self.header = header
        self.multiSelect = multiSelect
        self.options = options
        self.answerID = answerID
        self.allowsOther = allowsOther
        self.isSecret = isSecret
    }

    static func decode(_ json: JSONValue) -> AgentQuestion? {
        guard let question = json["question"]?.stringValue, !question.isEmpty else { return nil }

        return AgentQuestion(
            question: question,
            header: json["header"]?.stringValue ?? "",
            multiSelect: json["multiSelect"]?.boolValue ?? false,
            options: (json["options"]?.arrayValue ?? []).compactMap(Option.decode),
            answerID: json["unifieddevAnswerID"]?.stringValue,
            allowsOther: json["unifieddevAllowsOther"]?.boolValue ?? true,
            isSecret: json["isSecret"]?.boolValue ?? false
        )
    }
}

public enum AgentQuestionnaire {
    public static let toolName = "AskUserQuestion"

    public static let otherLabel = "Other"

    public static func isQuestion(toolName: String) -> Bool {
        toolName == Self.toolName
    }

    public static func questions(in input: JSONValue) -> [AgentQuestion] {
        (input["questions"]?.arrayValue ?? []).compactMap(AgentQuestion.decode)
    }

    public static func answered(_ input: JSONValue, answers: [String: String]) -> JSONValue {
        guard case .object(var object) = input else { return input }

        let filled = answers.filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard !filled.isEmpty else { return input }

        object["answers"] = .object(filled.mapValues { JSONValue.string($0) })

        return .object(object)
    }

    public static func joined(_ labels: [String]) -> String {
        labels.joined(separator: ", ")
    }

    public static func isComplete(_ questions: [AgentQuestion], answers: [String: String]) -> Bool {
        guard !questions.isEmpty else { return false }

        return questions.allSatisfy { question in
            let answer = answers[question.id] ?? ""
            return !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
