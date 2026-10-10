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

    private func session(in store: Store, named name: String = "w") async throws -> Session {
        let repo = try await store.upsert(Repo(name: "r-\(name)", path: "/tmp/r-\(name)"))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: name, branch: name, path: "/tmp/r-\(name)", baseBranch: "main"
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

    @Test("a secret answer is never written to the database, whatever the caller hands over")
    func secretsAreNeverWritten() async throws {
        let secretLine = """
        {"type":"control_request","request_id":"req-secret",\
        "request":{"subtype":"can_use_tool","tool_name":"AskUserQuestion",\
        "display_name":"AskUserQuestion","tool_use_id":"toolu_secret",\
        "input":{"questions":[\
        {"question":"Which token should it use?","unifieddevAnswerID":"q1","isSecret":true},\
        {"question":"Which host?","unifieddevAnswerID":"q2"}]}}}
        """
        let payload = Data(secretLine.utf8)
        let ask = try #require(PermissionAsk.decode(payload: payload))

        let written = try #require(
            AnsweredAsk.payload(of: payload, answers: ["q1": "sk-live-41", "q2": "Herd"])
        )

        #expect(!String(decoding: written, as: UTF8.self).contains("sk-live-41"))
        #expect(AnsweredAsk.answers(in: written) == [
            "q1": AgentQuestionnaire.hiddenAnswer, "q2": "Herd",
        ])

        let store = try makeTestStore()
        let session = try await session(in: store)
        try await store.appendPermissionAsk(sessionID: session.id, ask: ask)
        try await store.resolvePermissionAsk(
            id: ask.requestID,
            decision: PermissionDecision.answeredName,
            answers: ["q1": "sk-live-41", "q2": "Herd"]
        )

        let answers = try await store.permissionAskAnswers(sessionID: session.id)

        #expect(answers[ask.requestID]?["q1"] == AgentQuestionnaire.hiddenAnswer)
        #expect(answers[ask.requestID]?["q2"] == "Herd")
    }

    @Test("the answers read back are the answered ones, and only of the session asked for")
    func readingIsScoped() async throws {
        let store = try makeTestStore()
        let mine = try await session(in: store, named: "mine")
        let other = try await session(in: store, named: "other")

        try await store.appendPermissionAsk(sessionID: mine.id, ask: ask)
        try await store.resolvePermissionAsk(
            id: ask.requestID, decision: PermissionDecision.answeredName, answers: ["q1": "Postgres"]
        )

        let theirs = try #require(PermissionAsk.decode(payload: Data(
            Self.questionLine.replacingOccurrences(of: "req-questions", with: "req-theirs").utf8
        )))
        try await store.appendPermissionAsk(sessionID: other.id, ask: theirs)
        try await store.resolvePermissionAsk(
            id: theirs.requestID, decision: PermissionDecision.answeredName, answers: ["q1": "SQLite"]
        )

        let read = try await store.permissionAskAnswers(sessionID: mine.id)

        #expect(read.count == 1)
        #expect(read[ask.requestID]?["q1"] == "Postgres")
        #expect(read[theirs.requestID] == nil)
    }

    @Test("an ask settled some other way is not read back as answered, even holding answers")
    func onlyAnsweredDecisionsAreRead() async throws {
        let store = try makeTestStore()
        let session = try await session(in: store)
        try await store.appendPermissionAsk(sessionID: session.id, ask: ask)

        try await store.resolvePermissionAsk(
            id: ask.requestID, decision: PermissionAskOutcome.stopped, answers: ["q1": "Postgres"]
        )

        #expect(try await store.permissionAskAnswers(sessionID: session.id).isEmpty)
        #expect(try await store.permissionAskDecisions(sessionID: session.id)[ask.requestID]
            == PermissionAskOutcome.stopped)
    }

    @Test("an ask already settled takes neither a second decision nor answers into its question")
    func settledOnce() async throws {
        let store = try makeTestStore()
        let session = try await session(in: store)
        try await store.appendPermissionAsk(sessionID: session.id, ask: ask)

        try await store.resolvePermissionAsk(
            id: ask.requestID, decision: PermissionAskOutcome.abandoned
        )
        try await store.resolvePermissionAsk(
            id: ask.requestID,
            decision: PermissionDecision.answeredName,
            answers: ["q1": "Postgres"]
        )

        #expect(try await store.permissionAskDecisions(sessionID: session.id)[ask.requestID]
            == PermissionAskOutcome.abandoned)
        #expect(try await store.permissionAskAnswers(sessionID: session.id).isEmpty)
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
