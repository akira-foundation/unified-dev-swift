import Foundation
import Testing
@testable import Core

@Suite("Answered asks", .tags(.persistence), .scratchDirectory)
struct AnsweredAskTests {
    static let questionLine = """
    {"type":"control_request","request_id":"req-questions",\
    "request":{"subtype":"can_use_tool","tool_name":"AskUserQuestion",\
    "display_name":"AskUserQuestion","tool_use_id":"toolu_questions",\
    "input":{"questions":[\
    {"question":"Which database should this use?","header":"Storage",\
    "unifieddevAnswerID":"q1","options":[{"label":"SQLite"},{"label":"Postgres"}]},\
    {"question":"Where should it run?","header":"Host",\
    "unifieddevAnswerID":"q2","options":[{"label":"Herd"},{"label":"Docker"}]}]}}}
    """

    private var payload: Data { Data(Self.questionLine.utf8) }

    private var ask: PermissionAsk {
        PermissionAsk.decode(payload: payload)!
    }

    private func session(in store: Store) async throws -> Session {
        let repo = try await store.upsert(Repo(name: "r", path: "/tmp/r"))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "b", path: "/tmp/r-w", baseBranch: "main"
        ))
        return try await store.upsert(Session(workspaceID: workspace.id))
    }

    @Test("the answers are written into the question that was asked, and read back out of it")
    func roundTrip() throws {
        let answered = try #require(
            AnsweredAsk.payload(of: payload, answers: ["q1": "Postgres", "q2": "Herd"])
        )

        #expect(AnsweredAsk.answers(in: answered) == ["q1": "Postgres", "q2": "Herd"])
    }

    @Test("nothing else in the question is disturbed by the answers landing in it")
    func keepsTheQuestion() throws {
        let answered = try #require(
            AnsweredAsk.payload(of: payload, answers: ["q1": "SQLite"])
        )
        let reread = try #require(PermissionAsk.decode(payload: answered))

        #expect(reread.requestID == ask.requestID)
        #expect(reread.toolUseID == ask.toolUseID)
        #expect(reread.isQuestion)
        #expect(AgentQuestionnaire.questions(in: reread.input) == AgentQuestionnaire.questions(in: ask.input))
    }

    @Test("a question nobody answered is left exactly as it was")
    func nothingToWrite() {
        #expect(AnsweredAsk.payload(of: payload, answers: [:]) == nil)
        #expect(AnsweredAsk.answers(in: payload).isEmpty)
    }

    @Test("something that is not a request at all cannot be answered into")
    func notARequest() {
        let rubbish = Data("not json".utf8)

        #expect(AnsweredAsk.payload(of: rubbish, answers: ["q1": "SQLite"]) == nil)
        #expect(AnsweredAsk.answers(in: rubbish).isEmpty)
    }

    @Test("answering a question keeps the decision for months, not for the session")
    func survivesTheSession() async throws {
        let path = TestScratch.unique("answers") + ".sqlite"
        let first = try Store(path: path)
        let session = try await session(in: first)
        try await first.appendPermissionAsk(sessionID: session.id, ask: ask)

        try await first.resolvePermissionAsk(
            id: ask.requestID,
            decision: PermissionDecision.answeredName,
            answers: ["q1": "Postgres", "q2": "a managed box of my own"]
        )

        let second = try Store(path: path)
        let answers = try await second.permissionAskAnswers(sessionID: session.id)

        #expect(answers[ask.requestID]?["q1"] == "Postgres")
        #expect(answers[ask.requestID]?["q2"] == "a managed box of my own")
    }

    @Test("a decision that carries no answer leaves nothing to read back")
    func decisionsWithoutAnswers() async throws {
        let store = try makeTestStore()
        let session = try await session(in: store)
        try await store.appendPermissionAsk(sessionID: session.id, ask: ask)

        try await store.resolvePermissionAsk(
            id: ask.requestID, decision: PermissionDecision.deny(message: "no", endsTurn: false).storedName
        )

        #expect(try await store.permissionAskAnswers(sessionID: session.id).isEmpty)
        #expect(try await store.permissionAskDecisions(sessionID: session.id)[ask.requestID] == "deny")
    }

    @Test("the decision carries its own answers, and any other decision carries none")
    func answersOfADecision() {
        let input = AgentQuestionnaire.answered(ask.input, answers: ["q1": "SQLite"])

        #expect(PermissionDecision.answer(input: input).answers == ["q1": "SQLite"])
        #expect(PermissionDecision.allow(scope: .once).answers.isEmpty)
        #expect(PermissionDecision.deny(message: "no", endsTurn: false).answers.isEmpty)
    }
}
