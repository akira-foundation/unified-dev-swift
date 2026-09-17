import AppKit
import SwiftUI
import QuartzCore
import Core

@MainActor
enum TabProbe {
    private static let harness = ProbeHarness(subject: "tab")

    static var isRequested: Bool { harness.isRequested }

    private static var workspaceID: WorkspaceID? {
        ProbeHarness.value(for: "--tab-workspace").map(WorkspaceID.init)
    }

    private static var order: [String] {
        ProbeHarness.text("--tab-order", or: "chat").split(separator: ",").map(String.init)
    }

    private static var cycles: Int { ProbeHarness.count("--tab-cycles", or: 3) }

    private static var settle: Int { ProbeHarness.count("--tab-settle", or: 2500) }

    static func schedule() {
        Task { @MainActor in await run() }
    }

    static func attach(_ model: AppModel) {
        guard isRequested else { return }
        ProbeHarness.attach(model)
    }

    private static func run() async {
        if let driver = ProbeHarness.value(for: "--tab-driver"), driver != "programmatic" {
            harness.fail("the only driver is `programmatic`. See the head of TabProbe.swift")
        }

        let (window, contentView) = await harness.window()

        guard let app = ProbeHarness.appModel else { harness.fail("no app model") }
        guard let workspaceID else { harness.fail("--tab-workspace named no workspace") }
        app.selection = .workspace(workspaceID)

        try? await Task.sleep(for: .seconds(8))

        guard let workspace = app.existingModel(for: workspaceID) else {
            harness.fail("workspace \(workspaceID.rawValue) is not open")
        }

        let tabs = order.map { token -> (token: String, tab: PaneContent) in
            guard let tab = resolve(token, in: workspace) else {
                harness.fail("--tab-order named `\(token)`, which is not a tab this workspace can have")
            }
            return (token, tab)
        }
        try? await Task.sleep(for: .seconds(2))

        let ticker = Ticker(view: contentView)
        ticker.start()
        SwitchTrace.isEnabled = true

        var runs: [JSONValue] = []

        for entry in tabs {
            let run = await select(entry.tab, token: entry.token, of: workspace, ticker: ticker)
            runs.append(.object(run.merging(["pass": .string("cold")]) { current, _ in current }))
            try? await Task.sleep(for: .milliseconds(600))
        }

        for cycle in 0..<cycles {
            for entry in tabs {
                let run = await select(entry.tab, token: entry.token, of: workspace, ticker: ticker)
                let labels: [String: JSONValue] = [
                    "cycle": .integer(cycle), "pass": .string("warm"),
                ]
                runs.append(.object(run.merging(labels) { current, _ in current }))
                try? await Task.sleep(for: .milliseconds(600))
            }
        }

        SwitchTrace.isEnabled = false
        ticker.stop()

        let own: [String: JSONValue] = [
            "driver": .string("programmatic"),
            "workspace": .string(workspaceID.rawValue),
            "workspaceName": .string(workspace.workspace.name),
            "order": .strings(order),
            "cycles": .integer(cycles),
            "settleMs": .integer(settle),
            "sessionRows": .integer(workspace.activeTranscript?.rows.count ?? 0),
            "runs": .array(runs),
        ]
        harness.write(.object(own.merging(harness.conditions(window: window)) { mine, _ in mine }))
        exit(0)
    }

    private static func select(
        _ tab: PaneContent, token: String, of workspace: WorkspaceModel, ticker: Ticker
    ) async -> [String: JSONValue] {
        ticker.beginRun()
        PaneLayoutTiming.reset()
        PaneLayoutTiming.isEnabled = true
        TranscriptHoldCensus.reset()
        SwitchTrace.begin(workspaceID: workspace.workspace.id)
        FileHandle.standardError.write(
            Data("TAB \(token) \(Date().timeIntervalSince1970)\n".utf8)
        )

        WorkspaceTabsStore.shared.select(tab, in: workspace)

        try? await Task.sleep(for: .milliseconds(settle))
        PaneLayoutTiming.isEnabled = false

        return [
            "token": .string(token),
            "tab": .string(tab.id),
            "marks": SwitchTrace.timeline(),
            "frameCount": .integer(ticker.intervalsMs.count),
            "blocks": .numbers(ticker.blocksMs),
            "paneLayout": .map(PaneLayoutTiming.summary()),
            "panePasses": .map(PaneLayoutTiming.timeline()),
            "transcriptHold": .map(TranscriptHoldCensus.summary()),
            "worstFrameMs": .number(ticker.intervalsMs.max() ?? 0),
        ]
    }

    private static func resolve(_ token: String, in workspace: WorkspaceModel) -> PaneContent? {
        let id = workspace.workspace.id
        if token == "chat" {
            return WorkspaceTabsStore.shared.entries(in: workspace).first { $0.isChat }
        }
        if token.hasPrefix("chat:") {
            return .chat(SessionID(String(token.dropFirst("chat:".count))))
        }
        guard let kind = CenterTabKind(rawValue: token) else { return nil }
        let store = CenterTabStore.shared
        if let existing = store.tabs(for: id).first(where: { $0.kind == kind }) {
            return .tool(existing.id)
        }
        return .tool(store.add(kind: kind, workspaceID: id).id)
    }
}
