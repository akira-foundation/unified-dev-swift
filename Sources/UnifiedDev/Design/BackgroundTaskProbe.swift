import AppKit
import Core
import SwiftUI

#if DEBUG
@MainActor
enum BackgroundTaskProbe {
    private static let harness = ProbeHarness(subject: "background-task")

    static var isRequested: Bool { harness.isRequested }

    static func runAndExit() -> Never {
        guard Bundle.main.bundleIdentifier != "io.akira.unifieddev" else { exit(1) }
        NSApplication.shared.setActivationPolicy(.prohibited)
        Task { await run() }
        RunLoop.main.run()
        exit(1)
    }

    private static let title = "Create milestone, issue and branch, then the plan workspace"

    private static let script = """
    gh api repos/akira-foundation/unified-dev-swift/milestones -f title="Tasks"
    gh issue create --title "Clear finished tasks" --assignee @me
    git checkout -b feat/400-clear-finished-tasks --no-track origin/develop
    """

    private static var uncaptured: Subagent {
        Subagent(id: SubagentID("1"), description: title, taskType: "local_bash",
                 state: .completed, summary: title, elapsedSeconds: 3)
    }

    private static var failed: Subagent {
        Subagent(id: SubagentID("2"), description: "Run the core test suite", taskType: "local_bash",
                 state: .failed, summary: "exit code 1", outputFile: "/x", elapsedSeconds: 192)
    }

    private static var list: BackgroundTaskList {
        BackgroundTaskList(SubagentRoster([
            uncaptured, failed,
            Subagent(id: SubagentID("4"), description: "Run the browser scripts", taskType: "local_bash",
                     elapsedSeconds: 42),
        ]), stopsTasks: true)
    }

    private static func run() async {
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            await render(form(uncaptured, command: script, failure: .noFile), "uncaptured-\(name)", appearance)
            let printed = "Test run with 21 tests in 1 suite failed after 0.1 seconds.\nerror: fatalError"
            await render(form(failed, command: "./Tools/test-core.sh", printed: printed), "printed-\(name)", appearance)
            await render(
                BackgroundTaskListBody(list: list, onOpen: { _ in }, onStop: { _ in }, onClear: {})
                    .environment(\.controlActiveState, .active)
                    .background(Color(nsColor: .windowBackgroundColor)),
                "list-\(name)", appearance, size: CGSize(width: 320, height: 420)
            )
        }
        harness.write(.object(["rendered": .bool(true)]))
        exit(0)
    }

    private static func form(
        _ subagent: Subagent, command: String, printed: String = "", failure: SubagentOutput.Failure? = nil
    ) -> BackgroundCommandForm {
        BackgroundCommandForm(
            subagent: subagent, command: command, printed: printed, failure: failure, hasRead: true
        )
    }

    private static func render(
        _ view: some View, _ name: String, _ appearance: NSAppearance.Name,
        size: CGSize = CGSize(width: 680, height: 520)
    ) async {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: size)
        host.appearance = NSAppearance(named: appearance)
        let window = NSWindow(
            contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.appearance = NSAppearance(named: appearance)
        window.contentView = host
        window.layoutIfNeeded()
        try? await Task.sleep(for: .milliseconds(400))
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            harness.fail("no bitmap")
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let path = harness.outputPath + ".\(name).png"
        try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
}
#endif
