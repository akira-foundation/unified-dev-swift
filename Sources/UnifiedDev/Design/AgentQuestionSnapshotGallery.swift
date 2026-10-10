import SwiftUI
import Core

struct AgentQuestionSnapshotGallery: View {
    private static let storage = AgentQuestion(
        question: "Which database should the importer write to?",
        header: "Storage",
        options: [
            AgentQuestion.Option(
                label: "Postgres",
                description: "A server, a schema and a migration to run before the first import."
            ),
            AgentQuestion.Option(
                label: "SQLite",
                description: "One file beside the worktree, no server to keep alive."
            ),
        ],
        answerID: "q1"
    )

    private static let reader = AgentQuestion(
        question: "Which formats should the first version read?",
        header: "Reader",
        multiSelect: true,
        options: [
            AgentQuestion.Option(label: "CSV", description: "Comma separated, with a header row."),
            AgentQuestion.Option(label: "JSON Lines", description: "One object per line."),
            AgentQuestion.Option(label: "Excel", description: "A workbook, one sheet per table."),
        ],
        answerID: "q2"
    )

    private static let failure = AgentQuestion(
        question: "What should it do when the file is unreadable halfway through?",
        header: "Failure",
        options: [
            AgentQuestion.Option(
                label: "Stop and keep what landed",
                description: "The import is left half done, and says where it stopped."
            ),
            AgentQuestion.Option(
                label: "Roll the whole import back",
                description: "Nothing lands unless all of it does."
            ),
        ],
        answerID: "q3"
    )

    private func ask(_ questions: [AgentQuestion], id: String) -> PermissionAsk {
        PermissionAsk(
            requestID: id,
            toolName: AgentQuestionnaire.toolName,
            toolUseID: "toolu_\(id)",
            input: .object(["questions": .array(questions.map { question in
                .object([
                    "question": .string(question.question),
                    "header": .string(question.header),
                    "multiSelect": .bool(question.multiSelect),
                    "unifieddevAnswerID": .string(question.id),
                    "options": .array(question.options.map { option in
                        .object([
                            "label": .string(option.label),
                            "description": .string(option.description),
                        ])
                    }),
                ])
            })])
        )
    }

    private func slice(
        _ title: String,
        questions: [AgentQuestion],
        decision: String? = PermissionDecision.answeredName,
        answers: [String: String] = [:],
        isExpanded: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(Typo.micro)
                .foregroundStyle(Palette.textTertiary)
                .padding(.bottom, 4)

            AgentQuestionCard(
                ask: ask(questions, id: title),
                decision: decision,
                answers: answers,
                isExpanded: isExpanded
            )
            .padding(.horizontal, TranscriptLayout.inset)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            slice("Waiting", questions: [Self.storage], decision: nil)

            slice(
                "Answered by option",
                questions: [Self.storage],
                answers: ["q1": "Postgres"]
            )

            slice(
                "Answered in his own words",
                questions: [Self.storage],
                answers: ["q1": "a managed Postgres, with the schema in a migration"]
            )

            slice(
                "Three parts, answered whole",
                questions: [Self.storage, Self.reader, Self.failure],
                answers: [
                    "q1": "Postgres",
                    "q2": "CSV, JSON Lines",
                    "q3": "Roll the whole import back",
                ]
            )

            slice(
                "Reopened, with the choice marked",
                questions: [Self.storage],
                answers: ["q1": "Postgres"],
                isExpanded: true
            )

            slice("Left to the agent", questions: [Self.storage], decision: "deny")

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.windowBackground)
    }
}
