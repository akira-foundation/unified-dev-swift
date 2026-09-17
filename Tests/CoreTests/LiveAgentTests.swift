import Testing
import Foundation
@testable import Core

private let liveEnabled = ProcessInfo.processInfo.environment["UD_LIVE"] == "1"

@Suite("LiveAgent", .enabled(if: liveEnabled), .tags(.subprocess), .scratchDirectory)
struct LiveAgentTests {
    private func makeWorkspace() async throws -> (store: Store, session: Session, path: String, repo: TempRepo) {
        let repo = try await TempRepo()
        try repo.write("notes.txt", "the secret word is pelican\n")
        try await repo.commit("notes")

        let store = try makeTestStore("live")
        let manager = WorkspaceManager(store: store)
        let registered = try await manager.addRepository(at: repo.path)
        let workspace = try await manager.createWorkspace(repo: registered, prompt: "Live protocol check")
        let session = try await store.upsert(Session(
            workspaceID: workspace.id,
            model: "haiku",
            permissionMode: .bypassPermissions
        ))
        return (store, session, workspace.path, repo)
    }

    @Test("drives a real agent turn from prompt to result", .timeLimit(.minutes(5)))
    func drivesARealTurn() async throws {
        let (store, session, path, repo) = try await makeWorkspace()
        defer { repo.cleanUp() }

        let runner = AgentRunner(workspacePath: path, session: session, store: store)

        let collected = EventLog()
        let pump = Task {
            for await event in runner.events { collected.record(event) }
        }

        try await runner.send("Read notes.txt and reply with only the secret word, nothing else.")

        let deadline = Date().addingTimeInterval(180)
        while !collected.sawResult, Date() < deadline {
            try await Task.sleep(for: .milliseconds(200))
        }
        pump.cancel()

        #expect(collected.sawResult, "the agent never emitted a result event")
        #expect(collected.sawInit, "the agent never emitted an init event")
        #expect(collected.sawToolUse, "the agent never called a tool, so Read was not exercised")
        #expect(
            collected.unknownTopLevelTypes.isEmpty,
            "decoder did not recognise these top level types: \(collected.unknownTopLevelTypes)"
        )

        let stored = try await store.session(id: session.id)
        #expect(stored?.agentSessionID != nil)
        #expect(stored?.state == .idle)

        let rows = try await store.messages(sessionID: session.id)
        #expect(rows.count > 3)
        #expect(rows.map(\.seq) == Array(0..<rows.count))

        let toolRows = rows.filter { $0.kind == .toolUse }
        #expect(toolRows.isEmpty == false)
        for row in toolRows {
            let refID = try #require(row.refID)
            #expect(try await store.message(sessionID: session.id, refID: refID) != nil)
        }

        #expect(collected.resultSummary.lowercased().contains("pelican"))
    }

    @Test("resumes a session so context survives a relaunch", .timeLimit(.minutes(5)))
    func resumesASession() async throws {
        let (store, session, path, repo) = try await makeWorkspace()
        defer { repo.cleanUp() }

        let first = AgentRunner(workspacePath: path, session: session, store: store)
        let firstLog = EventLog()
        let firstPump = Task { for await event in first.events { firstLog.record(event) } }
        try await first.send("Remember the number 4271. Reply with just OK.")

        let deadline = Date().addingTimeInterval(120)
        while !firstLog.sawResult, Date() < deadline {
            try await Task.sleep(for: .milliseconds(200))
        }
        firstPump.cancel()
        #expect(firstLog.sawResult)

        let resumed = try #require(try await store.session(id: session.id))
        #expect(resumed.agentSessionID != nil)

        let second = AgentRunner(workspacePath: path, session: resumed, store: store)
        let secondLog = EventLog()
        let secondPump = Task { for await event in second.events { secondLog.record(event) } }
        try await second.send("What number did I ask you to remember? Reply with just the number.")

        let secondDeadline = Date().addingTimeInterval(120)
        while !secondLog.sawResult, Date() < secondDeadline {
            try await Task.sleep(for: .milliseconds(200))
        }
        secondPump.cancel()

        #expect(secondLog.sawResult)
        #expect(secondLog.resultSummary.contains("4271"), "resume did not carry the earlier turn")
    }

    @Test("cancelling a turn stops the process", .timeLimit(.minutes(3)))
    func cancelsATurn() async throws {
        let (store, session, path, repo) = try await makeWorkspace()
        defer { repo.cleanUp() }

        let runner = AgentRunner(workspacePath: path, session: session, store: store)
        let log = EventLog()
        let pump = Task { for await event in runner.events { log.record(event) } }

        try await runner.send("Count slowly from 1 to 500, one number per line.")
        try await Task.sleep(for: .seconds(4))
        #expect(await runner.isRunning)

        runner.cancelNow()

        let deadline = Date().addingTimeInterval(20)
        while await runner.isRunning, Date() < deadline {
            try await Task.sleep(for: .milliseconds(200))
        }
        pump.cancel()

        #expect(await runner.isRunning == false, "the process was still alive 20 seconds after cancelling")

        var stored = try await store.session(id: session.id)
        let settleBy = Date().addingTimeInterval(5)
        while stored?.state == .running, Date() < settleBy {
            try await Task.sleep(for: .milliseconds(100))
            stored = try await store.session(id: session.id)
        }
        #expect(stored?.state == .cancelled, "left the session in \(stored?.state.rawValue ?? "nil")")
    }
}

final class EventLog: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var sawInit = false
    private(set) var sawResult = false
    private(set) var sawToolUse = false
    private(set) var unknownCount = 0
    private(set) var unknownSamples: [String] = []
    private(set) var resultSummary = ""
    private var unknownTypes: Set<String> = []

    var unknownTopLevelTypes: Set<String> {
        lock.lock(); defer { lock.unlock() }
        return unknownTypes.subtracting(["stream_event"])
    }

    func record(_ event: AgentEvent) {
        lock.lock(); defer { lock.unlock() }
        switch event {
        case .initialized: sawInit = true
        case .toolUse: sawToolUse = true
        case .result(let result):
            sawResult = true
            resultSummary = result.summary
        case .unknown(let raw):
            unknownCount += 1
            let text = String(decoding: raw, as: UTF8.self)
            if let object = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
               let type = object["type"] as? String {
                unknownTypes.insert(type)
            }
            if unknownSamples.count < 3 {
                unknownSamples.append(String(text.prefix(200)))
            }
        default: break
        }
    }
}

@Suite("LiveNaming", .enabled(if: liveEnabled), .tags(.subprocess), .scratchDirectory)
struct LiveNamingTests {
    @Test("a real model names a real task, in a shape Unified Dev will accept", .timeLimit(.minutes(2)))
    func namesATask() async throws {
        let namer = WorkspaceNamer()
        let started = Date()

        let suggestion = try #require(await namer.suggest(
            task: "Fix the N+1 query on the invoices index page, it loads a customer per row",
            project: "billing",
            template: PromptRegistry.definition(for: .nameWorkspace).defaultTemplate
        ))

        #expect(!suggestion.name.isEmpty)
        #expect(suggestion.name.count <= WorkspaceNaming.nameLimit)
        #expect(!suggestion.name.contains("\n"))
        #expect(Git.isValidBranchName(suggestion.branch))

        #expect(Date().timeIntervalSince(started) < 60)
    }
}
