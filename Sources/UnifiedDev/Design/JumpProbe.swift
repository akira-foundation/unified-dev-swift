import AppKit
import SwiftUI
import QuartzCore
import Core

@MainActor
enum JumpProbe {
    private static let harness = ProbeHarness(subject: "jump")

    static var isRequested: Bool { harness.isRequested }

    private static var workspaceID: WorkspaceID? {
        ProbeHarness.value(for: "--jump-workspace").map(WorkspaceID.init)
    }

    private static var settle: Duration {
        .milliseconds(ProbeHarness.count("--jump-settle", or: 2_500))
    }

    static func schedule() {
        Task { @MainActor in await run() }
    }

    static func attach(_ model: AppModel) {
        guard isRequested else { return }
        ProbeHarness.attach(model)
    }

    private static func run() async {
        let (window, contentView) = await harness.window()

        guard let workspaceID else { harness.fail("--jump-workspace names no workspace") }
        OpenWorkspaceNotification.post(workspaceID)
        try? await Task.sleep(for: .seconds(8))

        guard let app = ProbeHarness.appModel else { harness.fail("no app model") }
        guard let model = app.existingModel(for: workspaceID) else {
            harness.fail("workspace \(workspaceID.rawValue) is not open")
        }
        guard let session = model.activeSession,
              let transcript = model.existingTranscript(for: session.id) else {
            harness.fail("workspace \(workspaceID.rawValue) has no conversation open")
        }
        guard let scroll = ProbeHarness.transcriptScrollView(in: contentView) else {
            harness.fail("no transcript NSScrollView found")
        }

        let travel = scroll.endOffset
        guard travel > 1 else {
            harness.fail("the transcript is shorter than its viewport, so there is nowhere to jump from")
        }

        harness.markStarted()

        var cases: [JSONValue] = []
        cases.append(await jump(named: "from the very top", to: 0, scroll: scroll, transcript: transcript))
        cases.append(await jump(named: "from the middle", to: travel / 2, scroll: scroll, transcript: transcript))
        cases.append(await jump(
            named: "from one screen up", to: travel - scroll.contentView.bounds.height,
            scroll: scroll, transcript: transcript
        ))
        cases.append(await jump(
            named: "from just above the end", to: travel - 120, scroll: scroll, transcript: transcript
        ))
        cases.append(await jumpWhileStreaming(scroll: scroll, transcript: transcript, travel: travel))

        let failures = cases.filter { !isPass($0) }.count

        harness.write(.object([
            "workspace": .string(workspaceID.rawValue),
            "workspaceName": .string(model.workspace.name),
            "sessionRows": .integer(transcript.rows.count),
            "scrollableHeight": .number(Double(travel)),
            "cases": .array(cases),
            "failures": .integer(failures),
        ].merging(harness.conditions(window: window)) { mine, _ in mine }))
        exit(0)
    }

    private static func jump(
        named name: String, to origin: CGFloat, scroll: NSScrollView, transcript: TranscriptModel
    ) async -> JSONValue {
        put(scroll, at: max(0, origin))
        try? await Task.sleep(for: .milliseconds(600))
        let before = scroll.distanceFromEnd

        transcript.jumpToLiveEnd()
        try? await Task.sleep(for: settle)

        return verdict(name: name, before: before, scroll: scroll)
    }

    private static func jumpWhileStreaming(
        scroll: NSScrollView, transcript: TranscriptModel, travel: CGFloat
    ) async -> JSONValue {
        put(scroll, at: travel / 2)
        try? await Task.sleep(for: .milliseconds(600))
        let before = scroll.distanceFromEnd

        transcript.jumpToLiveEnd()
        let text = String(repeating: "measured ", count: 6)
        for _ in 0..<40 {
            await transcript.acceptForProbe(.streamDelta(.text(text)))
            try? await Task.sleep(for: .milliseconds(50))
        }
        try? await Task.sleep(for: settle)

        var report = verdict(name: "while the tail is growing", before: before, scroll: scroll)
        if case .object(var fields) = report {
            fields["tailCharacters"] = .integer(transcript.streamingText.count)
            report = .object(fields)
        }
        return report
    }

    private static func verdict(name: String, before: CGFloat, scroll: NSScrollView) -> JSONValue {
        let after = scroll.distanceFromEnd
        return .object([
            "case": .string(name),
            "pointsFromEndBefore": .number(Double(before)),
            "pointsFromEndAfter": .number(Double(after)),
            "atEnd": .bool(scroll.isAtEnd),
            "wouldPassAsFollowing": .bool(after < ScrollEnd.threshold),
        ])
    }

    private static func isPass(_ report: JSONValue) -> Bool {
        guard case .object(let fields) = report, case .bool(let atEnd)? = fields["atEnd"] else {
            return false
        }
        return atEnd
    }

    private static func put(_ scroll: NSScrollView, at origin: CGFloat) {
        let clip = scroll.contentView
        clip.setBoundsOrigin(NSPoint(x: clip.bounds.origin.x, y: origin))
        scroll.reflectScrolledClipView(clip)
    }
}
