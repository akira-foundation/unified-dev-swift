import Testing
import Foundation
@testable import Core

@Suite("The delta reads a bounded amount", .scratchDirectory)
struct HandoffRowsCeilingTests {
    private let megabyte = String(repeating: "x", count: 1_000_000)

    private func makeChat(_ store: Store) async throws -> Session {
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "w", branch: "b", path: TestScratch.unique("tree"), baseBranch: "main"
        ))
        return try await store.upsert(Session(workspaceID: workspace.id, model: "m", agentKind: .claudeCode))
    }

    private func append(_ store: Store, _ session: Session, _ kind: MessageKind, _ json: JSONValue, ref: String? = nil) async throws {
        try await store.appendNext(sessionID: session.id, kind: kind, payload: Data(json.compactJSON.utf8), refID: ref)
    }

    private func owner(_ text: String) -> JSONValue {
        .object(["type": .string("user"), "message": .object(["content": .string(text)])])
    }

    private func use(id: String, input: [String: JSONValue]) -> JSONValue {
        .object([
            "type": .string("assistant"),
            "message": .object(["content": .array([.object([
                "type": .string("tool_use"), "id": .string(id), "name": .string("Write"), "input": .object(input),
            ])])]),
        ])
    }

    private func result(id: String, content: JSONValue, isError: Bool = false, meta: JSONValue? = nil) -> JSONValue {
        var line: [String: JSONValue] = [
            "type": .string("user"),
            "tool_use_result": .string(megabyte),
            "message": .object(["content": .array([.object([
                "type": .string("tool_result"), "tool_use_id": .string(id),
                "is_error": .bool(isError), "content": content,
            ])])]),
        ]
        if let meta { line["tool_result_meta"] = meta }
        return .object(line)
    }

    private func read(_ store: Store, _ session: Session) async throws -> [Message] {
        try await store.handoffRows(sessionID: session.id, afterSeq: -1, excludingSeq: nil)
    }

    private func payloadBytes(_ rows: [Message]) -> Int {
        rows.reduce(0) { $0 + $1.payload.count }
    }

    @Test("a huge tool call and result read as a small amount, however large the rows are")
    func hugeRowsReadSmall() async throws {
        let store = try makeTestStore("ceiling-bytes")
        let session = try await makeChat(store)
        try await append(store, session, .user, owner("go"))
        for index in 0..<8 {
            try await append(store, session, .toolUse, use(id: "a\(index)", input: [
                "file_path": .string("/tmp/out"), "content": .string(megabyte),
            ]), ref: "a\(index)")
            try await append(store, session, .toolResult, result(id: "a\(index)", content: .string(megabyte)), ref: "a\(index)")
        }

        let rows = try await read(store, session)

        #expect(rows.count == 17)
        #expect(payloadBytes(rows) < 16 * (ConversationHandoff.oversizedRowBytes + 1_000))
    }

    @Test("rows no delta uses are not read at all")
    func unusedKindsAreNotRead() async throws {
        let store = try makeTestStore("ceiling-kinds")
        let session = try await makeChat(store)
        try await append(store, session, .user, owner("go"))
        try await append(store, session, .system, .object(["output": .string(megabyte)]))
        try await append(store, session, .notice, .object(["output": .string(megabyte)]))
        try await append(store, session, .error, .object(["message": .string(megabyte)]))

        let rows = try await read(store, session)

        #expect(rows.map(\.kind) == [.user])
    }

    @Test("a cut result still says which call it answers, whether it failed, and how it began")
    func aCutResultKeepsWhatTheDeltaNeeds() async throws {
        let store = try makeTestStore("ceiling-decode")
        let session = try await makeChat(store)
        try await append(store, session, .user, owner("go"))
        try await append(store, session, .toolUse, use(id: "a", input: ["command": .string("git push")]), ref: "a")
        try await append(store, session, .toolResult, result(
            id: "a", content: .string("rejected by hook " + megabyte), isError: true,
            meta: .array([.object(["id": .string("a"), "non_execution_kind": .string("permission_denied")])])
        ), ref: "a")

        let rows = try await read(store, session)
        let cut = try #require(rows.last)
        let event = AgentEvent.decode(line: String(decoding: cut.payload, as: UTF8.self))

        guard case .toolResult(let decoded)? = event else {
            Issue.record("the cut row no longer decodes as a tool result")
            return
        }
        #expect(cut.payload.count < ConversationHandoff.oversizedRowBytes)
        #expect(decoded.toolUseID == "a")
        #expect(decoded.isError)
        #expect(decoded.refusal != nil)
        #expect(decoded.text.hasPrefix("rejected by hook"))
        #expect(cut.refID == "a")
    }

    @Test("a cut result whose content is a list of blocks keeps its first words and no image bytes")
    func aCutResultOfBlocksKeepsTheText() async throws {
        let store = try makeTestStore("ceiling-blocks")
        let session = try await makeChat(store)
        try await append(store, session, .toolResult, result(id: "a", content: .array([
            .object(["type": .string("text"), "text": .string("the first words")]),
            .object(["type": .string("image"), "source": .object(["data": .string(megabyte)])]),
        ])), ref: "a")

        let rows = try await read(store, session)
        let cut = try #require(rows.first)

        guard case .toolResult(let decoded)? = AgentEvent.decode(line: String(decoding: cut.payload, as: UTF8.self)) else {
            Issue.record("the cut row no longer decodes as a tool result")
            return
        }
        #expect(cut.payload.count < ConversationHandoff.oversizedRowBytes)
        #expect(decoded.text == "the first words")
    }

    @Test("a cut tool call keeps its target and its name, and loses the body")
    func aCutCallKeepsItsTarget() async throws {
        let store = try makeTestStore("ceiling-call")
        let session = try await makeChat(store)
        try await append(store, session, .toolUse, use(id: "a", input: [
            "file_path": .string("/tmp/out.txt"), "content": .string(megabyte),
        ]), ref: "a")

        let rows = try await read(store, session)
        let cut = try #require(rows.first)

        guard case .toolUse(let decoded)? = AgentEvent.decode(line: String(decoding: cut.payload, as: UTF8.self)) else {
            Issue.record("the cut row no longer decodes as a tool call")
            return
        }
        #expect(cut.payload.count < ConversationHandoff.oversizedRowBytes)
        #expect(decoded.name == "Write")
        #expect(decoded.id == "a")
        #expect(decoded.input["file_path"]?.stringValue == "/tmp/out.txt")
        #expect(decoded.input["content"] == nil)
    }

    @Test("an interrupted turn's cut result still reaches the agent as a line")
    func theDeltaShowsACutResult() async throws {
        let store = try makeTestStore("ceiling-delta")
        let session = try await makeChat(store)
        try await append(store, session, .user, owner("go"))
        try await append(store, session, .toolUse, use(id: "a", input: ["command": .string("make huge")]), ref: "a")
        try await append(store, session, .toolResult, result(id: "a", content: .string("first line " + megabyte)), ref: "a")

        let prompt = try await store.handoffTurn(
            "next", sessionID: session.id, deliveredSeq: nil, worktree: nil, contextWindow: nil
        )

        #expect(prompt.contains("make huge: completed"))
        #expect(prompt.contains("Result: first line"))
        #expect(prompt.count < 10_000)
    }

    @Test("a large row that is not JSON reads as nothing and breaks nothing")
    func aMalformedLargeRowBreaksNothing() async throws {
        let store = try makeTestStore("ceiling-malformed")
        let session = try await makeChat(store)
        try await store.appendNext(sessionID: session.id, kind: .toolResult, payload: Data(("{not json" + megabyte).utf8))

        let rows = try await read(store, session)

        #expect(rows.count == 1)
        #expect(payloadBytes(rows) < ConversationHandoff.oversizedRowBytes)
    }

    @Test("an ordinary row is read byte for byte")
    func anOrdinaryRowIsUntouched() async throws {
        let store = try makeTestStore("ceiling-ordinary")
        let session = try await makeChat(store)
        let line = result(id: "a", content: .string("short")).compactJSON.replacingOccurrences(of: megabyte, with: "brief")
        try await store.appendNext(sessionID: session.id, kind: .toolResult, payload: Data(line.utf8))

        let rows = try await read(store, session)

        #expect(rows.first?.payload == Data(line.utf8))
    }
}
