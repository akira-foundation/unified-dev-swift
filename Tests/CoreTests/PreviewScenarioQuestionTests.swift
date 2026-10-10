import Foundation
import Testing
@testable import Core

@Suite("A preview scenario that asks the owner something")
struct PreviewScenarioQuestionTests {
    private func scenario(_ json: String) throws -> PreviewScenario {
        try PreviewScenario.read(Data(json.utf8))
    }

    private func refusal(_ json: String) -> String {
        do {
            _ = try scenario(json)
            return ""
        } catch {
            return String(describing: error)
        }
    }

    private func card(_ parts: String) -> String {
        """
        {"projects":[{"name":"a","workspaces":[{"name":"w","branch":"w","chats":[
          {"title":"Plan","messages":[{"from":"agent","question":{"parts":[\(parts)]}}]}]}]}]}
        """
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
        #expect(
            refusal(#"""
                {"projects":[{"name":"a","workspaces":[{"name":"w","branch":"w","chats":[
                  {"title":"Plan","messages":[{"from":"user","question":{"parts":[
                    {"question":"Which one?"}]}}]}]}]}]}
                """#).contains("is asked by the owner")
        )
        #expect(
            refusal(#"""
                {"projects":[{"name":"a","workspaces":[{"name":"w","branch":"w","chats":[
                  {"title":"Plan","messages":[{"from":"agent","text":"Also this",
                    "question":{"parts":[{"question":"Which one?"}]}}]}]}]}]}
                """#).contains("also carries prose")
        )
    }

    @Test("a card half answered is refused, because no card is ever answered in halves")
    func halfAnswered() {
        #expect(
            refusal(card(#"{"question":"One?","answer":"Yes"},{"question":"Two?"}"#))
                .contains("answered whole or not at all")
        )
    }

    @Test("a question that asks nothing, or answers with nothing, is refused")
    func emptyShapes() {
        #expect(refusal(card("")).contains("a question asks nothing"))
        #expect(
            refusal(card(#"{"question":"One?","answer":"  "}"#))
                .contains("is answered with nothing")
        )
        #expect(
            refusal(#"""
                {"projects":[{"name":"a","workspaces":[{"name":"w","branch":"w","chats":[
                  {"title":"Plan","messages":[{"from":"agent"}]}]}]}]}
                """#).contains("says nothing and asks nothing")
        )
    }

    @Test("a part with no text, or asked twice on one card, is refused")
    func unusableParts() {
        #expect(refusal(card(#"{"question":"  "}"#)).contains("has no text"))
        #expect(
            refusal(card(#"{"question":"One?"},{"question":"One?"}"#))
                .contains("is asked twice in one card")
        )
    }

    @Test("an option with no label, or offered twice on one part, is refused")
    func unusableOptions() {
        #expect(
            refusal(card(#"{"question":"One?","options":["  "]}"#))
                .contains("has no label")
        )
        #expect(
            refusal(card(#"{"question":"One?","options":["This","This"]}"#))
                .contains("is offered twice")
        )
    }

    @Test("a part that takes one answer and is given several is refused")
    func oneAnswerGivenSeveral() {
        #expect(
            refusal(card(#"{"question":"One?","options":["This","That"],"answer":"This, That"}"#))
                .contains("takes one answer and is given several")
        )
        #expect(
            refusal(card(
                #"{"question":"One?","multiSelect":true,"options":["This","That"],"answer":"This, That"}"#
            )).isEmpty
        )
    }

    @Test("a secret part travels the whole way, and its answer is never what is written down")
    func secretParts() throws {
        let read = try scenario(card(
            #"{"question":"Which token?","isSecret":true,"answer":"sk-live-41"}"#
        ))
        let question = try #require(read.projects[0].workspaces[0].chats[0].messages[0].question)
        let payload = try #require(question.payload(requestID: "req-1", toolUseID: "toolu-1"))
        let ask = try #require(PermissionAsk.decode(payload: payload))
        let decoded = AgentQuestionnaire.questions(in: ask.input)

        #expect(decoded.first?.isSecret == true)
        #expect(!String(decoding: payload, as: UTF8.self).contains("sk-live-41"))

        let digest = try #require(
            AgentQuestionDigest.of(decoded, answers: AnsweredAsk.answers(in: payload)).first
        )

        #expect(digest.answer == AgentQuestionDigest.Answer.hidden)
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

        #expect(questions.count == 5)
        #expect(questions.filter { !$0.isAnswered }.count == 1)
        #expect(questions.contains { $0.parts.count > 1 })
        #expect(questions.contains { $0.parts.contains(where: \.isSecret) })

        let digests = questions.flatMap { question in
            AgentQuestionDigest.of(
                AgentQuestionnaire.questions(in: question.input), answers: question.answers
            )
        }

        #expect(digests.contains { $0.isTyped })
        #expect(digests.contains { !$0.isTyped && $0.isAnswered })
        #expect(digests.contains { $0.chosen.count > 1 })
        #expect(digests.contains { !$0.isAnswered })
        #expect(digests.contains { $0.answer == AgentQuestionDigest.Answer.hidden })
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
