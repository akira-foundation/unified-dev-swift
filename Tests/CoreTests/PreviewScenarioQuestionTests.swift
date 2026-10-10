import Foundation
import Testing
@testable import Core

@Suite("A preview scenario that asks the owner something")
struct PreviewScenarioQuestionTests {
    private func scenario(_ json: String) throws -> PreviewScenario {
        try PreviewScenario.read(Data(json.utf8))
    }

    @Test("a question reads with its parts, its options and the answer each part was given")
    func reading() throws {
        let read = try scenario(#"""
            {"projects":[{"name":"a","workspaces":[{"name":"w","branch":"w","chats":[
              {"title":"Plan","messages":[{"from":"agent","question":{"parts":[
                {"header":"Storage","question":"Which database?","answer":"Postgres",
                 "options":[{"label":"Postgres","description":"A server."},"SQLite"]}]}}]}]}]}]}
            """#)

        let question = try #require(read.projects[0].workspaces[0].chats[0].messages[0].question)
        let part = try #require(question.parts.first)

        #expect(part.header == "Storage")
        #expect(part.question == "Which database?")
        #expect(part.options.map(\.label) == ["Postgres", "SQLite"])
        #expect(part.options[0].description == "A server.")
        #expect(part.options[1].description.isEmpty)
        #expect(question.answers == ["q1": "Postgres"])
        #expect(question.isAnswered)
    }

    @Test("a question nobody answered is seeded waiting for an answer")
    func unanswered() throws {
        let read = try scenario(#"""
            {"projects":[{"name":"a","workspaces":[{"name":"w","branch":"w","chats":[
              {"title":"Plan","messages":[{"from":"agent","question":{"parts":[
                {"question":"Which one?","options":["This","That"]}]}}]}]}]}]}
            """#)

        let question = try #require(read.projects[0].workspaces[0].chats[0].messages[0].question)

        #expect(!question.isAnswered)
        #expect(question.answers.isEmpty)
    }

    @Test("the seeded question is one the app's own decoder reads back as a question")
    func payloadIsReal() throws {
        let question = PreviewScenario.Question(parts: [
            PreviewScenario.Question.Part(
                header: "Storage",
                question: "Which database?",
                options: [PreviewScenario.Question.Option(label: "Postgres")],
                answer: "Postgres"
            ),
            PreviewScenario.Question.Part(
                header: "Reader",
                question: "Which formats?",
                options: [PreviewScenario.Question.Option(label: "CSV")],
                multiSelect: true,
                answer: "words of my own"
            ),
        ])

        let payload = try #require(question.payload(requestID: "req-1", toolUseID: "toolu-1"))
        let ask = try #require(PermissionAsk.decode(payload: payload))
        let read = AgentQuestionnaire.questions(in: ask.input)

        #expect(ask.isQuestion)
        #expect(ask.requestID == "req-1")
        #expect(ask.toolUseID == "toolu-1")
        #expect(read.map(\.id) == ["q1", "q2"])
        #expect(read.map(\.question) == ["Which database?", "Which formats?"])
        #expect(read[1].multiSelect)
        #expect(AnsweredAsk.answers(in: payload) == ["q1": "Postgres", "q2": "words of my own"])
    }

    @Test("a question asked by the owner, or carrying prose as well, is refused")
    func refusedShapes() {
        #expect(throws: PreviewScenarioError.self) {
            try scenario(#"""
                {"projects":[{"name":"a","workspaces":[{"name":"w","branch":"w","chats":[
                  {"title":"Plan","messages":[{"from":"user","question":{"parts":[
                    {"question":"Which one?"}]}}]}]}]}]}
                """#)
        }
        #expect(throws: PreviewScenarioError.self) {
            try scenario(#"""
                {"projects":[{"name":"a","workspaces":[{"name":"w","branch":"w","chats":[
                  {"title":"Plan","messages":[{"from":"agent","text":"Also this",
                    "question":{"parts":[{"question":"Which one?"}]}}]}]}]}]}
                """#)
        }
    }

    @Test("a card half answered is refused, because no card is ever answered in halves")
    func halfAnswered() {
        #expect(throws: PreviewScenarioError.self) {
            try scenario(#"""
                {"projects":[{"name":"a","workspaces":[{"name":"w","branch":"w","chats":[
                  {"title":"Plan","messages":[{"from":"agent","question":{"parts":[
                    {"question":"One?","answer":"Yes"},{"question":"Two?"}]}}]}]}]}]}
                """#)
        }
    }

    @Test("a question that asks nothing, or answers with nothing, is refused")
    func emptyShapes() {
        #expect(throws: PreviewScenarioError.self) {
            try scenario(#"""
                {"projects":[{"name":"a","workspaces":[{"name":"w","branch":"w","chats":[
                  {"title":"Plan","messages":[{"from":"agent","question":{"parts":[]}}]}]}]}]}
                """#)
        }
        #expect(throws: PreviewScenarioError.self) {
            try scenario(#"""
                {"projects":[{"name":"a","workspaces":[{"name":"w","branch":"w","chats":[
                  {"title":"Plan","messages":[{"from":"agent","question":{"parts":[
                    {"question":"One?","answer":"  "}]}}]}]}]}]}
                """#)
        }
        #expect(throws: PreviewScenarioError.self) {
            try scenario(#"""
                {"projects":[{"name":"a","workspaces":[{"name":"w","branch":"w","chats":[
                  {"title":"Plan","messages":[{"from":"agent"}]}]}]}]}
                """#)
        }
    }

    @Test("the scenario the preview walkthrough uses holds every state a question can be in")
    func theScenarioOnDisk() throws {
        let root = URL(fileURLWithPath: #filePath)
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path
        let read = try PreviewScenario.read(
            path: root + "/Tools/scenarios/answered-questions.json"
        )
        let questions = read.projects[0].workspaces[0].chats[0].messages.compactMap(\.question)

        #expect(questions.count == 4)
        #expect(questions.filter { !$0.isAnswered }.count == 1)
        #expect(questions.contains { $0.parts.count > 1 })

        let digests = questions.flatMap { question in
            AgentQuestionDigest.of(
                AgentQuestionnaire.questions(in: question.input), answers: question.answers
            )
        }

        #expect(digests.contains { $0.isTyped })
        #expect(digests.contains { !$0.isTyped && $0.isAnswered })
        #expect(digests.contains { $0.chosen.count > 1 })
        #expect(digests.contains { !$0.isAnswered })
    }
}

@Suite("Seeding a question into a preview", .tags(.git, .subprocess), .scratchDirectory, .timeLimit(.minutes(1)))
struct PreviewScenarioQuestionSeedingTests {
    @Test("an answered question is seeded settled with its answer, and an unanswered one waits")
    func seeding() async throws {
        let root = TestScratch.unique("preview-questions")
        let manager = WorkspaceManager(
            store: try makeTestStore("preview-questions"),
            workspacesRoot: URL(fileURLWithPath: root + "/workspaces", isDirectory: true)
        )
        let seeder = PreviewScenarioSeeder(
            manager: manager, scratchRoot: PreviewIdentity.scratch(in: root)
        )

        _ = try await seeder.seed(PreviewScenario(projects: [
            PreviewScenario.Project(name: "lantern", workspaces: [
                PreviewScenario.Workspace(
                    name: "Importer",
                    branch: "importer",
                    chats: [PreviewScenario.Chat(title: "Decisions", messages: [
                        PreviewScenario.Line(from: .agent, question: PreviewScenario.Question(parts: [
                            PreviewScenario.Question.Part(
                                header: "Storage",
                                question: "Which database?",
                                options: [PreviewScenario.Question.Option(label: "Postgres")],
                                answer: "Postgres"
                            ),
                        ])),
                        PreviewScenario.Line(from: .agent, question: PreviewScenario.Question(parts: [
                            PreviewScenario.Question.Part(question: "Which formats?"),
                        ])),
                    ])],
                ),
            ]),
        ]))

        let repo = try #require(try await manager.store.repos().first)
        let workspace = try #require(try await manager.store.workspaces(repoID: repo.id).first)
        let session = try #require(try await manager.store.sessions(workspaceID: workspace.id).first)
        let messages = try await manager.store.messages(sessionID: session.id)
        let asks = messages.filter { $0.kind == .permissionAsk }

        #expect(asks.count == 2)

        let decisions = try await manager.store.permissionAskDecisions(sessionID: session.id)
        let answers = try await manager.store.permissionAskAnswers(sessionID: session.id)
        let pending = try await manager.store.pendingPermissionAsks(sessionID: session.id)

        #expect(decisions.count == 1)
        #expect(decisions.values.allSatisfy { $0 == PermissionDecision.answeredName })
        #expect(answers.count == 1)
        #expect(answers.values.first == ["q1": "Postgres"])
        #expect(pending.count == 1)
        #expect(AgentQuestionnaire.questions(in: pending[0].ask.input).map(\.question) == ["Which formats?"])
    }
}
