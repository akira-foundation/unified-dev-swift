import AppKit
import SwiftUI
import QuartzCore
import Core

@MainActor
enum ResizeProbe {
    private static let harness = ProbeHarness(subject: "resize")

    static var isRequested: Bool { harness.isRequested }

    private static var workspaceID: WorkspaceID? {
        ProbeHarness.value(for: "--resize-workspace").map(WorkspaceID.init)
    }

    private static var sweeps: Int { ProbeHarness.count("--resize-sweeps", or: 4) }
    private static var travel: CGFloat { ProbeHarness.points("--resize-travel", or: 240) }
    private static var step: CGFloat { ProbeHarness.points("--resize-step", or: 4) }
    private static var leavesWindowNarrow: Bool {
        CommandLine.arguments.contains("--resize-leave-narrow")
    }

    private static var pageURL: String { ProbeHarness.text("--resize-url", or: "") }

    private static var arrangement: String {
        ProbeHarness.text("--resize-arrangement", or: "chat+browser")
    }

    static func schedule() {
        Task { @MainActor in await run() }
    }

    private static func run() async {
        let (window, contentView) = await harness.window()

        guard let app = ProbeHarness.appModel else { harness.fail("no app model") }
        guard let workspaceID else { harness.fail("--resize-workspace named no workspace") }
        app.selection = .workspace(workspaceID)
        app.isInspectorVisible = true

        try? await Task.sleep(for: .seconds(8))

        guard let workspace = app.existingModel(for: workspaceID) else {
            harness.fail("workspace \(workspaceID.rawValue) is not open")
        }

        await arrange(workspace)

        try? await Task.sleep(for: .seconds(8))

        let transcriptScroll = ProbeHarness.transcriptScrollView(in: contentView)
        if let transcriptScroll {
            transcriptScroll.contentView.setBoundsOrigin(
                NSPoint(x: transcriptScroll.contentView.bounds.origin.x, y: transcriptScroll.endOffset)
            )
            transcriptScroll.reflectScrolledClipView(transcriptScroll.contentView)
        }
        try? await Task.sleep(for: .milliseconds(300))
        let scrollBefore = ProbeHarness.scrollPlace(transcriptScroll)

        let recorder = FrameRecorder(view: contentView) { [weak window] in
            window?.frame.width ?? 0
        }

        await drag(window, sweeps: 1, returnsToStart: true)
        try? await Task.sleep(for: .seconds(1))

        harness.markStarted()

        PaneLayoutTiming.reset()
        PaneLayoutTiming.isEnabled = true
        TranscriptHoldCensus.reset()
        recorder.start()
        let cpuBefore = ProbeHarness.mainThreadCPUSeconds()
        let wallBefore = CACurrentMediaTime()
        await drag(window, sweeps: sweeps, returnsToStart: !leavesWindowNarrow)
        let cpu = ProbeHarness.mainThreadCPUSeconds() - cpuBefore
        let wall = CACurrentMediaTime() - wallBefore
        recorder.stop()
        PaneLayoutTiming.isEnabled = false

        harness.write(report(
            recorder: recorder,
            window: window,
            workspace: workspace,
            cpu: cpu,
            wall: wall,
            scrollBefore: scrollBefore,
            scrollAfter: ProbeHarness.scrollPlace(transcriptScroll)
        ))
        exit(0)
    }

    private static func arrange(_ workspace: WorkspaceModel) async {
        let tabs = WorkspaceTabsStore.shared
        guard let chat = tabs.entries(in: workspace).first(where: { $0.isChat }) else {
            harness.fail("the workspace has no conversation to put beside a browser")
        }
        tabs.select(chat, in: workspace)

        for _ in 0..<16 {
            let layout = tabs.layout(of: chat)
            guard layout.paneCount > 1, let pane = layout.panes.last else { break }
            guard tabs.close(pane: pane, in: chat, of: workspace.workspace.id) else { break }
        }
        try? await Task.sleep(for: .seconds(2))

        guard arrangement != "chat" else { return }
        NewPane.open(.browser, in: workspace, url: pageURL) { content in
            tabs.split(tab: chat, axis: .horizontal, showing: content)
        }
    }

    private static func drag(_ window: NSWindow, sweeps: Int, returnsToStart: Bool) async {
        let start = window.frame
        for offset in offsets(sweeps: sweeps) {
            var frame = start
            frame.size.width = start.width + offset
            window.setFrame(frame, display: true)
            try? await Task.sleep(for: .microseconds(8_333))
        }
        var finish = start
        if !returnsToStart { finish.size.width -= travel }
        window.setFrame(finish, display: true)
        try? await Task.sleep(for: .milliseconds(300))
    }

    private static func offsets(sweeps: Int) -> [CGFloat] {
        var offsets: [CGFloat] = []
        for _ in 0..<sweeps {
            var x: CGFloat = 0
            while x > -travel { offsets.append(x); x -= step }
            while x < 0 { offsets.append(x); x += step }
        }
        return offsets
    }

    private static func report(
        recorder: FrameRecorder, window: NSWindow, workspace: WorkspaceModel,
        cpu: Double, wall: Double,
        scrollBefore: [String: JSONValue], scrollAfter: [String: JSONValue]
    ) -> JSONValue {
        let widths = recorder.widths
        let tabs = WorkspaceTabsStore.shared
        let panes = tabs.selectedTab(in: workspace).map { tabs.layout(of: $0).paneCount } ?? 0
        let steps = offsets(sweeps: sweeps).count

        let own: [String: JSONValue] = [
            "driver": .string("programmatic"),
            "arrangement": .string(arrangement),
            "workspace": .string(workspace.workspace.id.rawValue),
            "workspaceName": .string(workspace.workspace.name),
            "drawnRows": .integer(TranscriptDrawn.rows),
            "sessionRows": .integer(workspace.activeTranscript?.rows.count ?? 0),
            "panes": .integer(panes),
            "inspector": .bool(AppModel.probeInstance?.isInspectorVisible ?? false),
            "changedFiles": .integer(workspace.changedFiles.count),
            "scrollBefore": .object(scrollBefore),
            "scrollAfter": .object(scrollAfter),
            "widthMin": .number(Double(widths.min() ?? 0)),
            "widthMax": .number(Double(widths.max() ?? 0)),
            "widthSteps": .integer(Set(widths).count),
            "didResize": .bool((widths.max() ?? 0) - (widths.min() ?? 0) > 1),
            "steps": .integer(steps),
            "travel": .number(Double(travel)),
            "step": .number(Double(step)),
            "sweeps": .integer(sweeps),
            "leavesWindowNarrow": .bool(leavesWindowNarrow),
            "mainThreadCpuMs": .number(cpu * 1000),
            "wallMs": .number(wall * 1000),
            "mainThreadBusyFraction": .number(wall > 0 ? cpu / wall : 0),
            "cpuMsPerStep": .number(cpu * 1000 / Double(max(1, steps))),
            "paneLayout": .map(PaneLayoutTiming.summary()),
            "transcriptHold": .map(TranscriptHoldCensus.summary()),
        ]
        return .object(
            own
                .merging(ProbeHarness.frameTimings(recorder.intervals.map { $0 * 1000 })) { mine, _ in mine }
                .merging(harness.conditions(window: window)) { mine, _ in mine }
        )
    }
}
