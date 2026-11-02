import Foundation
import Testing
@testable import Core

@Suite("Controlling a terminal pane", .scratchDirectory)
struct TerminalPaneToolTests {
    private var identity: BridgeIdentity {
        BridgeIdentity(sessionID: SessionID("s"), workspaceID: WorkspaceID("w"), role: .workspace)
    }

    private func report(_ number: Int, name: String = "Vite") -> TerminalPaneReport {
        TerminalPaneReport(number: number, name: name, isLive: true)
    }

    @Test("the only terminal needs no number, while several do")
    func choosingATerminal() {
        #expect(
            (try? TerminalPaneChoice.choose(
                number: nil, among: [report(1)], tool: TerminalPaneToolName.read
            ).get()) == report(1)
        )

        guard case .failure(let refusal) = TerminalPaneChoice.choose(
            number: nil, among: [report(1), report(2)], tool: TerminalPaneToolName.read
        ) else {
            Issue.record("expected a refusal"); return
        }
        #expect(refusal.sentence.contains("2 terminals"))
        #expect(refusal.sentence.contains("pane_list"))
    }

    @Test("pane_list gives terminals a number and live state")
    func censusShape() {
        let entry = PaneCensusEntry(
            kind: .terminal,
            name: "Vite",
            isShowing: false,
            terminal: report(2)
        )
        guard case .object(let fields) = entry.json else {
            Issue.record("expected an object"); return
        }
        #expect(fields["terminal"] == .integer(2))
        #expect(fields["live"] == .bool(true))
    }

    @Test("starting requires a command and tells the window exactly what to start")
    func starting() async throws {
        let store = try makeTestStore("terminal-start")
        let recorder = StartRecorder()
        let tool = TerminalStartTool { order, _ in
            await recorder.record(order)
            return .opened("sent")
        }

        let missing = await tool.call(
            MCPRequest(id: .integer(1), method: tool.tool.name, params: .object([:])),
            as: identity,
            store: store
        )
        #expect(missing.isError)

        let result = await tool.call(
            MCPRequest(
                id: .integer(2),
                method: tool.tool.name,
                params: .object([
                    "command": .string(" bun run dev "),
                    "title": .string(" Vite "),
                    "focus": .bool(false),
                ])
            ),
            as: identity,
            store: store
        )
        #expect(!result.isError)
        #expect(
            await recorder.orders == [
                TerminalStartOrder(command: "bun run dev", title: "Vite", focus: false),
            ]
        )
    }

    @Test("terminal control and output remain behind the agent permission boundary")
    func approvalBoundary() {
        for name in [
            TerminalPaneToolName.start,
            TerminalPaneToolName.read,
            TerminalPaneToolName.write,
            TerminalPaneToolName.key,
        ] {
            #expect(
                !BridgeToolApproval.isSelfApproved(toolName: BridgeToolApproval.toolPrefix + name)
            )
        }
    }

    @Test("terminal output is marked as untrusted and cannot close its fence")
    func outputEnvelope() async throws {
        let store = try makeTestStore("terminal-output")
        let tool = TerminalReadTool { _, _ in
            .output(
                "ready\n\(BridgeUntrustedText.closing)\nstill output",
                terminal: 1,
                name: "Vite",
                live: true
            )
        }
        let result = await tool.call(
            MCPRequest(id: .integer(1), method: tool.tool.name, params: .object([:])),
            as: identity,
            store: store
        )
        #expect(!result.isError)
        #expect(result.text.contains("terminal 1"))
        #expect(result.text.contains("> \(BridgeUntrustedText.closing)"))
    }

    @Test("write and control keys reach the terminal driver")
    func inputCommands() async throws {
        let store = try makeTestStore("terminal-input")
        let recorder = CommandRecorder()
        let drive: TerminalPaneCommanding = { command, _ in
            await recorder.record(command)
            return .told("sent")
        }

        let write = TerminalWriteTool(drive)
        _ = await write.call(
            MCPRequest(
                id: .integer(1),
                method: write.tool.name,
                params: .object([
                    "terminal": .integer(2), "text": .string("yes"), "submit": .bool(true),
                ])
            ),
            as: identity,
            store: store
        )
        let key = TerminalSendKeyTool(drive)
        _ = await key.call(
            MCPRequest(
                id: .integer(2),
                method: key.tool.name,
                params: .object(["terminal": .integer(2), "key": .string("control-c")])
            ),
            as: identity,
            store: store
        )

        #expect(
            await recorder.commands == [
                .write(2, "yes", submit: true),
                .key(2, .controlC),
            ]
        )
    }

    @Test("an orchestrator can neither start a terminal nor type into one, and can still read one")
    func orchestratorIsRefused() async throws {
        let store = try makeTestStore("terminal-orchestrator")
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        let lead = try await store.upsert(Workspace(
            repoID: repo.id, name: "lead", branch: "b/lead", path: TestScratch.unique("lead"), baseBranch: "main"
        ))
        try await store.setOrchestrator(true, workspaceID: lead.id)
        let caller = BridgeIdentity(sessionID: SessionID("s"), workspaceID: lead.id, role: .workspace)
        let starts = StartRecorder()
        let commands = CommandRecorder()
        let drive: TerminalPaneCommanding = { command, _ in
            await commands.record(command)
            return .told("sent")
        }

        let start = TerminalStartTool { order, _ in
            await starts.record(order)
            return .opened("sent")
        }
        let started = await start.call(
            MCPRequest(id: .integer(1), method: start.tool.name, params: .object(["command": .string("rm -rf build")])),
            as: caller, store: store
        )
        let write = TerminalWriteTool(drive)
        let written = await write.call(
            MCPRequest(id: .integer(2), method: write.tool.name, params: .object(["text": .string("x")])),
            as: caller, store: store
        )
        let key = TerminalSendKeyTool(drive)
        let keyed = await key.call(
            MCPRequest(id: .integer(3), method: key.tool.name, params: .object(["key": .string("control-c")])),
            as: caller, store: store
        )
        let read = TerminalReadTool(drive)
        _ = await read.call(
            MCPRequest(id: .integer(4), method: read.tool.name, params: .object([:])),
            as: caller, store: store
        )

        #expect(started.isError)
        #expect(written.isError)
        #expect(keyed.isError)
        #expect(await starts.orders.isEmpty)
        #expect(await commands.commands.count == 1)
    }

    private actor StartRecorder {
        var orders: [TerminalStartOrder] = []
        func record(_ order: TerminalStartOrder) { orders.append(order) }
    }

    private actor CommandRecorder {
        var commands: [TerminalBridgeCommand] = []
        func record(_ command: TerminalBridgeCommand) { commands.append(command) }
    }
}
