import Foundation

extension PreviewScenario {
    public struct Question: Sendable, Equatable, Codable {
        public struct Option: Sendable, Equatable, Codable {
            public var label: String
            public var description: String

            public init(label: String, description: String = "") {
                self.label = label
                self.description = description
            }

            public init(from decoder: Decoder) throws {
                if let label = try? decoder.singleValueContainer().decode(String.self) {
                    self.label = label
                    description = ""
                    return
                }
                let container = try decoder.container(keyedBy: CodingKeys.self)
                label = try container.decode(String.self, forKey: .label)
                description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
            }
        }

        public struct Part: Sendable, Equatable, Codable {
            public var header: String
            public var question: String
            public var options: [Option]
            public var multiSelect: Bool
            public var isSecret: Bool
            public var answer: String?

            public init(
                header: String = "",
                question: String,
                options: [Option] = [],
                multiSelect: Bool = false,
                isSecret: Bool = false,
                answer: String? = nil
            ) {
                self.header = header
                self.question = question
                self.options = options
                self.multiSelect = multiSelect
                self.isSecret = isSecret
                self.answer = answer
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                header = try container.decodeIfPresent(String.self, forKey: .header) ?? ""
                question = try container.decode(String.self, forKey: .question)
                options = try container.decodeIfPresent([Option].self, forKey: .options) ?? []
                multiSelect = try container.decodeIfPresent(Bool.self, forKey: .multiSelect) ?? false
                isSecret = try container.decodeIfPresent(Bool.self, forKey: .isSecret) ?? false
                answer = try container.decodeIfPresent(String.self, forKey: .answer)
            }
        }

        public var parts: [Part]

        public init(parts: [Part]) {
            self.parts = parts
        }

        public static func answerID(at index: Int) -> String { "q\(index + 1)" }

        public var answers: [String: String] {
            var answers: [String: String] = [:]
            for (index, part) in parts.enumerated() {
                guard let answer = part.answer, !answer.isEmpty else { continue }
                answers[Self.answerID(at: index)] = answer
            }
            return answers
        }

        public var isAnswered: Bool { !answers.isEmpty }

        public var input: JSONValue {
            .object(["questions": .array(parts.enumerated().map { index, part in
                .object([
                    "question": .string(part.question),
                    "header": .string(part.header),
                    "multiSelect": .bool(part.multiSelect),
                    "isSecret": .bool(part.isSecret),
                    "unifieddevAnswerID": .string(Self.answerID(at: index)),
                    "options": .array(part.options.map { option in
                        .object([
                            "label": .string(option.label),
                            "description": .string(option.description),
                        ])
                    }),
                ])
            })]
        )}

        public func payload(requestID: String, toolUseID: String) -> Data? {
            let envelope = JSONValue.object([
                "type": .string("control_request"),
                "request_id": .string(requestID),
                "request": .object([
                    "subtype": .string("can_use_tool"),
                    "tool_name": .string(AgentQuestionnaire.toolName),
                    "display_name": .string(AgentQuestionnaire.toolName),
                    "tool_use_id": .string(toolUseID),
                    "input": isAnswered
                        ? AgentQuestionnaire.answered(input, answers: answers)
                        : input,
                ]),
            ])
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.withoutEscapingSlashes]
            return try? encoder.encode(envelope)
        }

        var problems: [String] {
            var problems: [String] = []

            if parts.isEmpty { problems.append("a question asks nothing") }

            var seen = Set<String>()

            for part in parts {
                if part.question.trimmingCharacters(in: .whitespaces).isEmpty {
                    problems.append("a part of a question has no text")
                }
                if !seen.insert(part.question).inserted {
                    problems.append("question \"\(part.question)\" is asked twice in one card")
                }
                var labels = Set<String>()
                for option in part.options {
                    if option.label.trimmingCharacters(in: .whitespaces).isEmpty {
                        problems.append("an option of \"\(part.question)\" has no label")
                    }
                    if !labels.insert(option.label).inserted {
                        problems.append(
                            "option \"\(option.label)\" is offered twice on \"\(part.question)\""
                        )
                    }
                }
                if let answer = part.answer, answer.trimmingCharacters(in: .whitespaces).isEmpty {
                    problems.append(
                        "\"\(part.question)\" is answered with nothing, which is not an answer"
                    )
                }
            }

            let answered = parts.filter { $0.answer != nil }.count
            if answered > 0, answered < parts.count {
                problems.append(
                    "a card has to be answered whole or not at all, and this one answers "
                        + "\(answered) of \(parts.count)"
                )
            }

            return problems
        }
    }
}
