import AppKit
import SwiftUI
import Core

@MainActor
enum SwitchProbe {
    private static let harness = ProbeHarness(subject: "switch")

    static var isRequested: Bool { harness.isRequested }
    private static var sidebarSelection: Binding<SidebarSelection?>?

    static func attachSidebarSelection(_ selection: Binding<SidebarSelection?>?) {
        guard isRequested, driver == "sidebar" else { return }
        sidebarSelection = selection
    }

    private static var order: [WorkspaceID] {
        ProbeHarness.text("--switch-order", or: "")
            .split(separator: ",")
            .map { WorkspaceID(String($0)) }
    }

    private static var cycles: Int { ProbeHarness.count("--switch-cycles", or: 3) }
    private static var driver: String { ProbeHarness.text("--switch-driver", or: "programmatic") }
    private static var settle: Int { ProbeHarness.count("--switch-settle", or: 4000) }
    private static var scrollSteps: Int { ProbeHarness.count("--switch-scroll", or: 400) }

    static func schedule() {
        Task { @MainActor in await run() }
    }

    static func attach(_ model: AppModel) {
        guard isRequested else { return }
        ProbeHarness.attach(model)
    }

    private static func run() async {
        let (window, contentView) = await harness.window()

        guard !order.isEmpty else { harness.fail("--switch-order named no workspaces") }

        try? await Task.sleep(for: .seconds(4))

        if driver == "click" {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            try? await Task.sleep(for: .milliseconds(600))
        }

        let ticker = Ticker(view: contentView)
        ticker.start()
        SwitchTrace.isEnabled = true

        var runs: [JSONValue] = []

        for id in order {
            let run = await switchTo(id, contentView: contentView, ticker: ticker)
            runs.append(.object(run.merging(["pass": .string("cold")]) { current, _ in current }))
            try? await Task.sleep(for: .milliseconds(800))
        }

        for cycle in 0..<cycles {
            for id in order {
                let run = await switchTo(id, contentView: contentView, ticker: ticker)
                let labels: [String: JSONValue] = [
                    "cycle": .integer(cycle), "pass": .string("warm"),
                ]
                runs.append(.object(run.merging(labels) { current, _ in current }))
                try? await Task.sleep(for: .milliseconds(800))
            }
        }

        let kept = await keepsItsPlace(contentView: contentView, ticker: ticker)

        let rapid = await rapidSwitches(contentView: contentView, ticker: ticker)
        let background = await SwitchBackgroundProbe.run(order: order)

        SwitchTrace.isEnabled = false
        ticker.stop()

        let own: [String: JSONValue] = [
            "driver": .string(driver),
            "order": .strings(order.map(\.rawValue)),
            "cycles": .integer(cycles),
            "settleMs": .integer(settle),
            "runs": .array(runs),
            "rapid": .object(rapid),
            "backgroundUpdates": background,
            "keepsItsPlace": .object(kept),
        ]
        harness.write(.object(own.merging(harness.conditions(window: window)) { mine, _ in mine }))
        exit(0)
    }

    @discardableResult
    private static func switchTo(
        _ id: WorkspaceID, contentView: NSView, ticker: Ticker
    ) async -> [String: JSONValue] {
        guard let app = ProbeHarness.appModel else {
            FileHandle.standardError.write(Data("switch probe: no app model\n".utf8))
            return [:]
        }
        ticker.beginRun()
        PaneLayoutTiming.reset()
        PaneLayoutTiming.isEnabled = true
        TranscriptHoldCensus.reset()
        let name = app.workspaces.first { $0.id == id }?.name ?? id.rawValue
        FileHandle.standardError.write(
            Data("SWITCH \(name) \(Date().timeIntervalSince1970)\n".utf8)
        )

        var sidebarFrames: FrameRecorder?
        switch driver {
        case "click": await click(row: id, contentView: contentView)
        case "sidebar": sidebarFrames = selectSidebar(row: id, contentView: contentView)
        default: app.selection = .workspace(id)
        }

        try? await Task.sleep(for: .milliseconds(settle))
        PaneLayoutTiming.isEnabled = false
        sidebarFrames?.stop()

        return [
            "sidebarHighlightedBeforeActivation": sidebarFrames.map {
                .bool($0.widths.contains(1) && $0.widths.contains(2))
            } ?? .null,

            "workspace": .string(id.rawValue),
            "name": .string(name),
            "drawnRows": .integer(TranscriptDrawn.rows),
            "place": .object(ProbeHarness.scrollPlace(
                ProbeHarness.transcriptScrollView(in: contentView)
            )),
            "marks": SwitchTrace.timeline(),
            "frameCount": .integer(ticker.intervalsMs.count),
            "blocks": .numbers(ticker.blocksMs),
            "paneLayout": .map(PaneLayoutTiming.summary()),
            "panePasses": .map(PaneLayoutTiming.timeline()),
            "transcriptHold": .map(TranscriptHoldCensus.summary()),
            "worstFrameMs": .number(ticker.intervalsMs.max() ?? 0),
        ]
    }

    private static func keepsItsPlace(
        contentView: NSView, ticker: Ticker
    ) async -> [String: JSONValue] {
        guard let app = ProbeHarness.appModel, order.count >= 2 else { return [:] }
        let top = order[0]
        let bottom = order[order.count - 1]
        var report: [String: JSONValue] = [:]

        app.selection = .workspace(top)
        try? await Task.sleep(for: .milliseconds(settle))
        if let scroll = ProbeHarness.transcriptScrollView(in: contentView) {
            for _ in 0..<scrollSteps {
                ProbeHarness.wheel(scroll, by: 300)
                try? await Task.sleep(for: .milliseconds(8))
            }
            try? await Task.sleep(for: .seconds(2))
            report["topLeft"] = .object(ProbeHarness.scrollPlace(scroll))
            report["topRemembered"] = .object(remembered(for: top, in: app))
        }

        app.selection = .workspace(bottom)
        try? await Task.sleep(for: .milliseconds(settle))
        report["bottomLeft"] = .object(ProbeHarness.scrollPlace(
            ProbeHarness.transcriptScrollView(in: contentView)
        ))

        var visits: [JSONValue] = []
        for step in 0..<4 {
            let target = step.isMultiple(of: 2) ? top : bottom
            await switchTo(target, contentView: contentView, ticker: ticker)
            let place = ProbeHarness.scrollPlace(
                ProbeHarness.transcriptScrollView(in: contentView)
            )
            visits.append(.object([
                "step": .integer(step),
                "workspace": .string(target == top ? "topOne" : "bottomOne"),
                "place": .object(place),
            ]))
        }
        report["visits"] = .array(visits)

        app.selection = .workspace(top)
        try? await Task.sleep(for: .milliseconds(settle))
        if let scroll = ProbeHarness.transcriptScrollView(in: contentView) {
            for _ in 0..<200 {
                ProbeHarness.wheel(scroll, by: -300)
                try? await Task.sleep(for: .milliseconds(8))
            }
            try? await Task.sleep(for: .seconds(2))
            var reached = ProbeHarness.scrollPlace(scroll)
            reached["drawnRows"] = .integer(TranscriptDrawn.rows)
            if let model = app.existingModel(for: top),
               let session = model.activeSession,
               let transcript = model.existingTranscript(for: session.id) {
                reached["sessionRows"] = .integer(transcript.rows.count)
            }
            report["reachesTheEnd"] = .object(reached)
        }
        return report
    }

    private static func remembered(for id: WorkspaceID, in app: AppModel) -> [String: JSONValue] {
        guard let model = app.existingModel(for: id),
              let session = model.activeSession,
              let state = model.panePosition(pane: PaneContent.chat(session.id).id, session: session.id)
        else { return ["found": .bool(false)] }
        return [
            "found": .bool(true),
            "anchorSeq": state.anchorSeq.map { .integer($0) } ?? .null,
            "offset": .number(state.offset),
            "isAtLiveEnd": .bool(state.isAtLiveEnd),
            "rowCount": .integer(state.rowCount),
            "drawnStart": .integer(state.drawn.start),
            "drawnEnd": .integer(state.drawn.end),
        ]
    }

    private static func rapidSwitches(
        contentView: NSView, ticker: Ticker
    ) async -> [String: JSONValue] {
        guard let app = ProbeHarness.appModel, order.count >= 2 else { return [:] }
        let first = order[0]
        let second = order[order.count - 1]

        var flips: [JSONValue] = []
        for step in 0..<8 {
            let target = step.isMultiple(of: 2) ? first : second
            if driver == "sidebar" {
                selectSidebar(row: target, contentView: contentView)?.stop()
            } else {
                app.selection = .workspace(target)
            }
            try? await Task.sleep(for: .milliseconds(driver == "sidebar" ? 2 : 120))
            flips.append(.object(["step": .integer(step), "selected": .string(target.rawValue)]))
        }

        try? await Task.sleep(for: .seconds(8))

        let settled = app.selection.workspaceID
        let model = settled.flatMap { app.existingModel(for: $0) }
        let paths = model?.changedFiles.prefix(4).map(\.path) ?? []
        return [
            "flips": .array(flips),
            "settled": .string(settled?.rawValue ?? ""),
            "settledName": .string(app.workspaces.first { $0.id == settled }?.name ?? ""),
            "changedFileCount": .integer(model?.changedFiles.count ?? 0),
            "changedFileSample": .strings(paths),
            "worktree": .string(model?.workspace.path ?? ""),
            "isLoadingChanges": .bool(model?.isLoadingChanges ?? false),
            "sessionCount": .integer(model?.sessions.count ?? 0),
            "fileTreeRoots": .integer(model?.fileTree[""]?.count ?? 0),
            "fileTreeSample": .strings((model?.fileTree[""] ?? []).prefix(3).map(\.name)),
            "sessionTitles": .strings(model?.sessions.map(\.title) ?? []),
            "transcriptRows": .integer(model?.activeTranscript?.rows.count ?? 0),
            "otherWorkspaceFileCount": .integer(
                app.existingModel(for: settled == first ? second : first)?.changedFiles.count ?? 0
            ),
        ]
    }

    private static func selectSidebar(row id: WorkspaceID, contentView: NSView) -> FrameRecorder? {
        guard let app = ProbeHarness.appModel, let sidebarSelection else { return nil }
        let frames = FrameRecorder(view: contentView) {
            guard sidebarSelection.wrappedValue == .workspace(id) else { return 0 }
            return app.selection.workspaceID == id ? 2 : 1
        }
        frames.start()
        sidebarSelection.wrappedValue = .workspace(id)
        return frames
    }

    private static func click(row id: WorkspaceID, contentView: NSView) async {
        guard let app = ProbeHarness.appModel else { return }
        guard let window = contentView.window,
              let name = app.workspaces.first(where: { $0.id == id })?.name,
              let rect = rowRect(named: name, in: contentView) else {
            FileHandle.standardError.write(Data("switch probe: no sidebar row for \(id)\n".utf8))
            app.selection = .workspace(id)
            return
        }

        let inWindow = contentView.convert(CGPoint(x: rect.midX, y: rect.midY), to: nil)
        let onScreen = window.convertPoint(toScreen: inWindow)
        guard let screen = window.screen ?? NSScreen.main else { return }
        let flipped = CGPoint(x: onScreen.x, y: screen.frame.maxY - onScreen.y)

        let pid = ProcessInfo.processInfo.processIdentifier
        await harness.onEventThread(polling: .milliseconds(2)) {
            ProbeHarness.post(.leftMouseDown, at: flipped, pid: pid)
            Thread.sleep(forTimeInterval: 0.03)
            ProbeHarness.post(.leftMouseUp, at: flipped, pid: pid)
        }
    }

    private static func rowRect(named name: String, in root: NSView) -> CGRect? {
        var found: CGRect?
        func walk(_ view: NSView) {
            if found != nil { return }
            if view.className.contains("TableRowView") || view.className.contains("ListRow") {
                if label(of: view)?.contains(name) == true {
                    found = view.convert(view.bounds, to: root)
                    return
                }
            }
            for subview in view.subviews { walk(subview) }
        }
        walk(root)
        return found
    }

    private static func label(of view: NSView) -> String? {
        var parts: [String] = []
        func walk(_ view: NSView) {
            if let text = view.accessibilityLabel(), !text.isEmpty { parts.append(text) }
            if let value = view.accessibilityValue() as? String, !value.isEmpty { parts.append(value) }
            for subview in view.subviews { walk(subview) }
        }
        walk(view)
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}
