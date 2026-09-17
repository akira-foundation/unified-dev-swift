import AppKit
import SwiftUI
import QuartzCore
import Core

@MainActor
enum ScrollProbe {
    private static let harness = ProbeHarness(subject: "scroll")

    static var isRequested: Bool { harness.isRequested }

    private static var workspace: String? { ProbeHarness.value(for: "--scroll-workspace") }
    private static var sweeps: Int { ProbeHarness.count("--scroll-sweeps", or: 4) }
    private static var warm: Bool { ProbeHarness.count("--scroll-warm", or: 1) != 0 }
    private static var composer: Double? { ProbeHarness.value(for: "--scroll-composer").flatMap(Double.init) }
    private static var step: CGFloat { ProbeHarness.points("--scroll-step", or: 24) }

    static func schedule() {
        Task { @MainActor in await run() }
    }

    private static func run() async {
        let (window, contentView) = await harness.window()

        if let workspace {
            OpenWorkspaceNotification.post(WorkspaceID(workspace))
            try? await Task.sleep(for: .seconds(8))
        }

        guard let scroll = ProbeHarness.transcriptScrollView(in: contentView) else {
            let windows = NSApp.windows.map { "\($0.title) \($0.frame)" }
            FileHandle.standardError.write(Data("windows: \(windows)\n".utf8))
            harness.fail("no transcript NSScrollView found")
        }

        if let composer {
            guard let transcript = ProbeHarness.appModel?.selectedModel?.activeTranscript else {
                harness.fail("no composer transcript")
            }
            let storedDraft = transcript.draft
            await growComposer(to: composer, scroll: scroll, transcript: transcript)
            harness.write(report(
                recorder: FrameRecorder(view: contentView) { 0 }, travel: 0, wall: 0,
                window: window, scroll: scroll, heightBefore: scroll.documentView?.frame.height ?? 0
            ))
            transcript.draft = storedDraft
            exit(0)
        }

        let heightBefore = scroll.documentView?.frame.height ?? 0
        guard scroll.endOffset > 1 else {
            harness.fail("the transcript is shorter than its viewport, so there is nothing to scroll")
        }

        let recorder = FrameRecorder(view: contentView) { [weak scroll] in
            scroll?.contentView.bounds.origin.y ?? 0
        }

        if warm {
            await sweep(scroll, travel: scroll.endOffset, sweeps: 1)
            try? await Task.sleep(for: .seconds(1))
        }

        await documentToStopChanging(scroll)

        let travel = scroll.endOffset

        harness.markStarted()

        PaneLayoutTiming.reset()
        PaneLayoutTiming.isEnabled = true
        TranscriptHoldCensus.reset()

        recorder.start()
        documentHeights.removeAll()
        frames.removeAll()
        let wallBefore = CACurrentMediaTime()
        await sweep(scroll, travel: travel, sweeps: sweeps)
        let wall = CACurrentMediaTime() - wallBefore
        recorder.stop()
        PaneLayoutTiming.isEnabled = false

        harness.write(report(
            recorder: recorder, travel: travel, wall: wall, window: window, scroll: scroll,
            heightBefore: heightBefore
        ))
        exit(0)
    }

    private static func growComposer(
        to points: Double, scroll: NSScrollView, transcript: TranscriptModel
    ) async {
        nudge(scroll)
        try? await Task.sleep(for: .seconds(1))
        transcript.draft = Array(
            repeating: "Composer sizing probe.",
            count: max(1, Int(points / ComposerTextEditor.lineHeight))
        ).joined(separator: "\n")
        try? await Task.sleep(for: .seconds(3))
        nudge(scroll)
        try? await Task.sleep(for: .seconds(1))
    }

    private static func documentToStopChanging(_ scroll: NSScrollView) async {
        var last = scroll.documentView?.frame.height ?? 0
        var still = 0
        for _ in 0..<100 {
            try? await Task.sleep(for: .milliseconds(100))
            let now = scroll.documentView?.frame.height ?? 0
            still = abs(now - last) <= 0.5 ? still + 1 : 0
            last = now
            if still >= 5 { return }
        }
    }

    private static func climb() -> [String: JSONValue] {
        var upward: [(Frame, Double)] = []
        for (index, frame) in frames.enumerated() where index > 0 {
            let previous = frames[index - 1]
            guard frame.offset < previous.offset else { continue }
            upward.append((frame, (frame.at - previous.at) * 1000))
        }
        guard upward.count >= 25 else { return ["climbBands": .array([])] }
        let top = upward.map(\.0.offset).max() ?? 1
        let bands = 5
        var out: [JSONValue] = []
        for band in 0..<bands {
            let high = top * Double(bands - band) / Double(bands)
            let low = top * Double(bands - band - 1) / Double(bands)
            let inBand = upward.filter { $0.0.offset <= high && $0.0.offset > low }
            guard !inBand.isEmpty else { continue }
            let gaps = inBand.map(\.1).sorted()
            let calls = (inBand.last?.0.noteCalls ?? 0) - (inBand.first?.0.noteCalls ?? 0)
            let rows = (inBand.last?.0.notedRows ?? 0) - (inBand.first?.0.notedRows ?? 0)
            let cells = (inBand.last?.0.cellsBuilt ?? 0) - (inBand.first?.0.cellsBuilt ?? 0)
            let cellMs = ((inBand.last?.0.cellSeconds ?? 0) - (inBand.first?.0.cellSeconds ?? 0)) * 1000
            let noteMs = ((inBand.last?.0.noteSeconds ?? 0) - (inBand.first?.0.noteSeconds ?? 0)) * 1000
            out.append(.object([
                "band": .integer(band),
                "fromEnd": .number(low),
                "frames": .integer(inBand.count),
                "medianMs": .number(ProbeStats.percentile(0.5, of: gaps)),
                "p95Ms": .number(ProbeStats.percentile(0.95, of: gaps)),
                "noteCalls": .integer(abs(calls)),
                "notedRows": .integer(abs(rows)),
                "cellsBuilt": .integer(abs(cells)),
                "cellMs": .number(abs(cellMs)),
                "noteMs": .number(abs(noteMs)),
            ]))
        }
        return ["climbBands": .array(out)]
    }

    private static func documentMovement() -> [String: JSONValue] {
        let heights = documentHeights
        var moves = 0
        var worst: CGFloat = 0
        for (index, height) in heights.enumerated() where index > 0 {
            let step = abs(height - heights[index - 1])
            if step > 0.5 {
                moves += 1
                worst = max(worst, step)
            }
        }
        return [
            "documentMoves": .integer(moves),
            "documentMovedShare":
                .number(heights.isEmpty ? 0 : Double(moves) / Double(heights.count)),
            "worstDocumentMove": .number(Double(worst)),
            "documentSweepMin": .number(Double(heights.min() ?? 0)),
            "documentSweepMax": .number(Double(heights.max() ?? 0)),
        ]
    }

    private static func nudge(_ scroll: NSScrollView) {
        let origin = scroll.contentView.bounds.origin
        scroll.contentView.setBoundsOrigin(CGPoint(x: origin.x, y: max(0, origin.y - 1)))
        scroll.reflectScrolledClipView(scroll.contentView)
    }

    private static func sweep(_ scroll: NSScrollView, travel: CGFloat, sweeps: Int) async {
        for _ in 0..<sweeps {
            await travelTo(scroll, from: travel, to: 0)
            await travelTo(scroll, from: 0, to: travel)
        }
    }

    private static var documentHeights: [CGFloat] = []

    private struct Frame {
        var offset: CGFloat
        var at: Double
        var noteCalls: Int
        var notedRows: Int
        var cellsBuilt: Int
        var cellSeconds: Double
        var noteSeconds: Double
    }

    private static var frames: [Frame] = []

    private static func travelTo(_ scroll: NSScrollView, from: CGFloat, to: CGFloat) async {
        let direction: CGFloat = to > from ? 1 : -1
        var offset = from
        while (direction > 0 && offset < to) || (direction < 0 && offset > to) {
            offset += step * direction
            offset = direction > 0 ? min(offset, to) : max(offset, to)
            scroll.contentView.setBoundsOrigin(
                CGPoint(x: scroll.contentView.bounds.origin.x, y: offset)
            )
            scroll.reflectScrolledClipView(scroll.contentView)
            documentHeights.append(scroll.documentView?.frame.height ?? 0)
            frames.append(Frame(
                offset: offset,
                at: CACurrentMediaTime(),
                noteCalls: TranscriptHoldCensus.noteCalls,
                notedRows: TranscriptHoldCensus.notedRows,
                cellsBuilt: TranscriptHoldCensus.cellsBuilt,
                cellSeconds: TranscriptHoldCensus.cellSeconds,
                noteSeconds: TranscriptHoldCensus.noteSeconds
            ))
            try? await Task.sleep(for: .milliseconds(8))
        }
    }

    private static func report(
        recorder: FrameRecorder, travel: CGFloat, wall: Double, window: NSWindow,
        scroll: NSScrollView, heightBefore: CGFloat
    ) -> JSONValue {
        let offsets = recorder.widths
        let own: [String: JSONValue] = [
            "wallSeconds": .number(wall),
            "travelPoints": .number(Double(travel)),
            "documentHeightBefore": .number(Double(heightBefore)),
            "documentHeightAfter": .number(Double(scroll.documentView?.frame.height ?? 0)),
            "viewportHeight": .number(Double(scroll.contentView.bounds.height)),
            "offsetMin": .number(Double(offsets.min() ?? 0)),
            "offsetMax": .number(Double(offsets.max() ?? 0)),
            "didScroll": .bool((offsets.max() ?? 0) - (offsets.min() ?? 0) > 1),
            "step": .number(Double(step)),
            "sweeps": .integer(sweeps),
            "transcriptHold": .map(TranscriptHoldCensus.summary()),
            "paneLayout": .map(PaneLayoutTiming.summary()),
            "panePasses": .map(PaneLayoutTiming.timeline()),
        ].merging(documentMovement()) { mine, _ in mine }
            .merging(climb()) { mine, _ in mine }
        return .object(
            own
                .merging(ProbeHarness.frameTimings(recorder.intervals.map { $0 * 1000 })) { mine, _ in mine }
                .merging(harness.conditions(window: window)) { mine, _ in mine }
        )
    }
}
