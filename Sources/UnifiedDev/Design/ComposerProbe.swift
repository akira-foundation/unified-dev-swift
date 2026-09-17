import AppKit
import SwiftUI
import QuartzCore
import Core

@MainActor
enum ComposerProbe {
    private static let harness = ProbeHarness(subject: "composer")

    static var isRequested: Bool { harness.isRequested }

    private static var drivenTranscript: TranscriptModel?

    private static var workspaceID: WorkspaceID? {
        ProbeHarness.value(for: "--composer-workspace").map(WorkspaceID.init)
    }

    private static var travel: CGFloat { ProbeHarness.points("--composer-travel", or: 320) }
    private static var step: CGFloat { ProbeHarness.points("--composer-step", or: 24) }

    private static var settleMs: Int { ProbeHarness.count("--composer-settle", or: 1200) }

    private static var band: Int { ProbeHarness.count("--composer-band", or: 400) }

    private static var paneWidth: CGFloat { ProbeHarness.points("--composer-pane-width", or: 420) }

    private static var arrangement: String {
        ProbeHarness.text("--composer-arrangement", or: "chat")
    }

    private static var pageURL: String { ProbeHarness.text("--composer-url", or: "") }

    static func schedule() {
        Task { @MainActor in await run() }
    }

    private static func run() async {
        let (window, contentView) = await harness.window()

        guard let app = ProbeHarness.appModel else { harness.fail("no app model") }
        guard let workspaceID else { harness.fail("--composer-workspace named no workspace") }
        app.selection = .workspace(workspaceID)
        app.isInspectorVisible = true

        try? await Task.sleep(for: .seconds(8))

        guard let workspace = app.existingModel(for: workspaceID) else {
            harness.fail("workspace \(workspaceID.rawValue) is not open")
        }
        await arrange(workspace)
        try? await Task.sleep(for: .seconds(8))

        guard let scroll = ProbeHarness.transcriptScrollView(in: contentView) else {
            harness.fail("no transcript NSScrollView found")
        }
        guard let hold = TranscriptStateDump.holdView(in: contentView) else {
            harness.fail("no TranscriptHoldView found, so this is not the transcript's pane")
        }
        let pane = TranscriptStateDump.Pane(
            scroll: scroll,
            hold: hold,
            table: scroll.documentView as? NSTableView,
            coordinator: hold.delegate as? TranscriptTable.Coordinator
        )
        guard pane.coordinator != nil else {
            harness.fail("the hold view has no coordinator, so no row facts can be read")
        }

        await pin(window, pane: pane, in: contentView)

        guard let transcript = workspace.activeTranscript else { harness.fail("no active transcript") }
        drivenTranscript = transcript
        let storedDraft = transcript.draft
        transcript.draft = ""
        try? await Task.sleep(for: .seconds(1))

        scroll.contentView.setBoundsOrigin(
            NSPoint(x: scroll.contentView.bounds.origin.x, y: scroll.endOffset)
        )
        scroll.reflectScrolledClipView(scroll.contentView)
        try? await Task.sleep(for: .milliseconds(400))

        TranscriptHoldCensus.reset()
        harness.markStarted()
        let before = dump(pane)

        let drag = await drive(from: 0, to: travel, by: step, pane: pane)
        try? await Task.sleep(for: .milliseconds(settleMs))
        let afterTaller = dump(pane)

        await scrollAbout(pane)
        try? await Task.sleep(for: .milliseconds(settleMs))
        let afterScrolling = dump(pane)

        await nudgeWindowWidth(window)
        try? await Task.sleep(for: .milliseconds(settleMs))
        let afterWindowResize = dump(pane)

        let dragBack = await drive(from: travel, to: 0, by: -step, pane: pane)
        transcript.draft = storedDraft
        drivenTranscript = nil

        harness.write(report(
            window: window,
            pane: pane,
            workspace: workspace,
            before: before,
            afterTaller: afterTaller,
            afterScrolling: afterScrolling,
            afterWindowResize: afterWindowResize,
            drag: drag,
            dragBack: dragBack
        ), echo: false)
        exit(0)
    }

    private static func arrange(_ workspace: WorkspaceModel) async {
        let tabs = WorkspaceTabsStore.shared
        guard let chat = tabs.entries(in: workspace).first(where: { $0.isChat }) else {
            harness.fail("the workspace has no conversation to drag a composer in")
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

    private static func pin(_ window: NSWindow, pane: TranscriptStateDump.Pane, in root: NSView) async {
        if let raw = ProbeHarness.value(for: "--window-size"),
           let size = ProbeStats.windowSize(raw) {
            window.setContentSize(size)
            window.layoutIfNeeded()
            try? await Task.sleep(for: .milliseconds(500))
        }
        guard let split = detailSplitView(in: root) else {
            harness.fail("no split view holds the transcript, so its width cannot be pinned")
        }
        for _ in 0..<12 {
            let current = pane.hold.bounds.width
            guard abs(current - paneWidth) > 1 else { return }
            let column = split.arrangedSubviews[0].frame.width
            split.setPosition(column + (paneWidth - current), ofDividerAt: 0)
            window.layoutIfNeeded()
            try? await Task.sleep(for: .milliseconds(250))
            guard abs(pane.hold.bounds.width - current) < 1 else { continue }
            var frame = window.frame
            frame.size.width += paneWidth - pane.hold.bounds.width
            window.setFrame(frame, display: true)
            window.layoutIfNeeded()
            try? await Task.sleep(for: .milliseconds(250))
        }
        let widths = split.arrangedSubviews.map { Int($0.frame.width) }
        harness.fail(
            "the transcript pane is \(Int(pane.hold.bounds.width)) points wide and the run asked "
                + "for \(Int(paneWidth)). The window is \(Int(window.frame.width)) and the split "
                + "is \(widths). Nothing measured at another width is comparable, so this run is "
                + "refused."
        )
    }

    private static func detailSplitView(in root: NSView) -> NSSplitView? {
        var best: (view: NSSplitView, depth: Int)?
        func walk(_ view: NSView, _ depth: Int) {
            if let split = view as? NSSplitView, split.arrangedSubviews.count == 2,
               let first = split.arrangedSubviews.first, TranscriptStateDump.holdView(in: first) != nil {
                if best == nil || depth > (best?.depth ?? 0) { best = (split, depth) }
            }
            for subview in view.subviews { walk(subview, depth + 1) }
        }
        walk(root, 0)
        return best?.view
    }

    private static func drive(
        from start: CGFloat,
        to finish: CGFloat,
        by step: CGFloat,
        pane: TranscriptStateDump.Pane
    ) async -> [JSONValue] {
        guard step != 0 else { return [] }
        var samples: [JSONValue] = []
        var height = start
        while step > 0 ? height < finish : height > finish {
            height += step
            let clamped = step > 0 ? min(height, finish) : max(height, finish)
            drivenTranscript?.draft = Array(
                repeating: "Composer sizing probe.",
                count: max(1, Int(clamped / ComposerTextEditor.lineHeight))
            ).joined(separator: "\n")
            pane.scroll.window?.layoutIfNeeded()
            try? await Task.sleep(for: .microseconds(8_333))
            samples.append(sample(at: clamped, pane: pane))
        }
        return samples
    }

    private static func scrollAbout(_ pane: TranscriptStateDump.Pane) async {
        let screen = pane.scroll.contentView.bounds.height
        guard screen > 1 else { return }
        for _ in 0..<6 {
            ProbeHarness.wheel(pane.scroll, by: screen / 2, steps: 2)
            try? await Task.sleep(for: .milliseconds(250))
        }
        for _ in 0..<6 {
            ProbeHarness.wheel(pane.scroll, by: -screen / 2, steps: 2)
            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    private static func nudgeWindowWidth(_ window: NSWindow) async {
        let start = window.frame
        var wider = start
        wider.size.width = start.width + 4
        window.setFrame(wider, display: true)
        try? await Task.sleep(for: .milliseconds(600))
        window.setFrame(start, display: true)
        try? await Task.sleep(for: .milliseconds(600))
    }

    private static func sample(at height: CGFloat, pane: TranscriptStateDump.Pane) -> JSONValue {
        let clip = pane.scroll.contentView
        let visible = pane.table.map { $0.rows(in: clip.documentVisibleRect).length } ?? -1
        return .object([
            "editorHeight": .number(Double(height)),
            "viewportHeight": .number(Double(clip.bounds.height)),
            "viewportWidth": .number(Double(clip.bounds.width)),
            "contentHeight": .number(Double(pane.scroll.documentView?.frame.height ?? 0)),
            "offset": .number(Double(clip.bounds.origin.y)),
            "overshoot": .number(Double(clip.bounds.origin.y - pane.scroll.endOffset)),
            "visibleRows": .integer(visible),
            "silenced": .integer(TranscriptHoldCensus.silencedRows),
            "widthMismatches": .integer(TranscriptHoldCensus.widthMismatches),
            "cached": .integer(pane.coordinator?.heightCacheCount ?? -1),
            "cacheWidth": .number(pane.coordinator?.heightCacheWidth ?? 0),
            "scrollAlpha": .number(Double(pane.scroll.alphaValue)),
            "held": .bool(pane.hold.isHolding),
        ])
    }

    private static func dump(_ pane: TranscriptStateDump.Pane) -> [String: JSONValue] {
        TranscriptStateDump.state(of: pane, band: band)
    }

    private static func report(
        window: NSWindow,
        pane: TranscriptStateDump.Pane,
        workspace: WorkspaceModel,
        before: [String: JSONValue],
        afterTaller: [String: JSONValue],
        afterScrolling: [String: JSONValue],
        afterWindowResize: [String: JSONValue],
        drag: [JSONValue],
        dragBack: [JSONValue]
    ) -> JSONValue {
        let tabs = WorkspaceTabsStore.shared
        let panes = tabs.selectedTab(in: workspace).map { tabs.layout(of: $0).paneCount } ?? 0
        func number(_ phase: [String: JSONValue], _ field: String) -> Double {
            switch phase[field] {
            case .number(let value)?: return value
            case .integer(let value)?: return Double(value)
            default: return 0
            }
        }
        let lengths = drag.compactMap { sample -> Double? in
            guard case .object(let fields) = sample,
                  case .number(let height)? = fields["contentHeight"] else { return nil }
            return height
        }
        let low = lengths.min() ?? 0
        let high = lengths.max() ?? 0
        let swing = low > 0 ? high / low : 0
        let grew = (lengths.last ?? 0) > (lengths.first ?? 0)

        let own: [String: JSONValue] = [
            "paneWidth": .number(Double(pane.hold.bounds.width)),
            "windowWidth": .number(Double(window.frame.width)),
            "tableRows": .integer(pane.table?.numberOfRows ?? -1),
            "sessionRows": .integer(workspace.activeTranscript?.rows.count ?? 0),
            "arrangement": .string(arrangement),
            "panes": .integer(panes),
            "version": .string(
                Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
            ),
            "build": .string(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"),
            "workspace": .string(workspace.workspace.id.rawValue),
            "workspaceName": .string(workspace.workspace.name),
            "driver": .string("draftLines"),
            "drawnRows": .integer(TranscriptDrawn.rows),
            "travel": .number(Double(travel)),
            "step": .number(Double(step)),
            "band": .integer(band),
            "settleMs": .integer(settleMs),

            "largestGuess": .number(max(
                number(before, "largestGuess"),
                max(number(afterTaller, "largestGuess"), number(afterScrolling, "largestGuess"))
            )),

            "guessRatio": .number(
                number(before, "measuredPointsPerRow") > 0
                    ? number(before, "largestGuess") / number(before, "measuredPointsPerRow")
                    : 0
            ),
            "documentSwingDuringDrag": .number(swing),
            "documentAtDragStart": .number(lengths.first ?? 0),
            "documentAtDragEnd": .number(lengths.last ?? 0),
            "documentMinDuringDrag": .number(low),
            "documentMaxDuringDrag": .number(high),
            "documentGrewDuringDrag": .bool(grew),
            "reproduced": .bool(swing >= 2 || [before, afterTaller, afterScrolling, afterWindowResize]
                .contains { number($0, "misplacedCells") > 0 }),

            "before": .object(before),
            "afterTaller": .object(afterTaller),
            "afterScrolling": .object(afterScrolling),
            "afterWindowResize": .object(afterWindowResize),
            "steps": .array(drag),
            "stepsBack": .array(dragBack),
            "widthMismatches": .integer(TranscriptHoldCensus.widthMismatches),
            "cellsBuilt": .integer(TranscriptHoldCensus.cellsBuilt),
            "screenEstimated": .integer(TranscriptHoldCensus.screenEstimated),
            "screenEstimatedSettled": .integer(TranscriptHoldCensus.screenEstimatedSettled),
            "screensSeen": .integer(TranscriptHoldCensus.screensSeen),
            "mismatches": .array(TranscriptHoldCensus.mismatches.map { TranscriptStateDump.json(of: $0) }),
            "silences": .array(TranscriptHoldCensus.silences.map { TranscriptStateDump.json(of: $0) }),
            "transcriptHold": .map(TranscriptHoldCensus.summary()),
            "lostBefore": .integer(Int(number(before, "lostRows"))),
            "lostAfterDrag": .integer(Int(number(afterTaller, "lostRows"))),
            "lostAfterScrolling": .integer(Int(number(afterScrolling, "lostRows"))),
            "lostAfterWindowResize": .integer(Int(number(afterWindowResize, "lostRows"))),
        ]
        return .object(own.merging(harness.conditions(window: window)) { mine, _ in mine })
    }
}
