import AppKit
import Core
import Observation
import SwiftUI

#if DEBUG
@MainActor
enum WelcomeLayoutProbe {
    static var isRequested: Bool { CommandLine.arguments.contains("--welcome-layout-probe") }

    static func runAndExit() -> Never {
        guard Bundle.main.bundleIdentifier == "io.akira.unifieddev.welcome-probe",
              SetupRehearsal.report != nil else { exit(1) }
        NSApplication.shared.setActivationPolicy(.prohibited)
        Task { await run() }
        RunLoop.main.run()
        exit(1)
    }

    private static func run() async {
        var failures: [String] = []
        var checks = 0
        func check(_ condition: Bool, _ message: String) {
            checks += 1
            if !condition { failures.append(message) }
        }
        for disableAnimations in [false, true] {
            let fixture = WelcomeLayoutFixture()
            let host = WelcomeHostingController(
                rootView: WelcomeLayoutContent(fixture: fixture)
                    .transaction { if disableAnimations { $0.disablesAnimations = true } },
                contentWidth: WelcomeView.contentWidth
            )
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: host.fittingContentSize()),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered, defer: false
            )
            window.isReleasedWhenClosed = false
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.contentViewController = host
            await settle(window)
            let greetingHeight = window.frame.height

            for visit in 0..<3 {
                withAnimation(disableAnimations ? nil : Motion.pane) { fixture.showsChecks = true }
                await settle(window)
                check(window.frame.height > greetingHeight, "checks did not grow the window")
                check(abs(host.view.bounds.height - host.fittingContentSize().height) < 1,
                      "checks do not fit the window")
                check(!window.isVisible && !window.isKeyWindow, "probe showed its window")
                withAnimation(disableAnimations ? nil : Motion.pane) { fixture.showsChecks = false }
                await settle(window)
                check(abs(window.frame.height - greetingHeight) < 1,
                      "visit \(visit), animations disabled \(disableAnimations): greeting \(greetingHeight), returned \(window.frame.height), ideal \(host.fittingContentSize().height)")
            }
            window.contentViewController = nil
        }
        let result: JSONValue = .object([
            "checks": .integer(checks), "passed": .bool(failures.isEmpty),
            "failures": .strings(failures),
        ])
        if let data = try? JSONEncoder().encode(result) { FileHandle.standardOutput.write(data) }
        exit(failures.isEmpty ? 0 : 1)
    }

    private static func settle(_ window: NSWindow) async {
        for _ in 0..<12 {
            window.layoutIfNeeded()
            window.contentView?.layoutSubtreeIfNeeded()
            window.contentView?.displayIfNeeded()
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
}

@MainActor
@Observable
private final class WelcomeLayoutFixture {
    var showsChecks = false
    let inspection = SetupInspection(rehearsal: SetupRehearsal.report)
    let registration = CommandLineRegistration(source: { nil })
    let agentDefault = WelcomeAgentDefault(store: { nil })
}

private struct WelcomeLayoutContent: View {
    let fixture: WelcomeLayoutFixture

    var body: some View {
        Group {
            if fixture.showsChecks {
                WelcomeView(inspection: fixture.inspection, registration: fixture.registration,
                            agentDefault: fixture.agentDefault, start: .checks, onFinish: {})
                    .transition(.opacity)
            } else {
                WelcomeSheet(
                    title: "Welcome to Unified Dev",
                    subtitle: "A worktree, an agent and a branch for every task you describe",
                    actionTitle: OnboardingFlow.startTitle,
                    action: { fixture.showsChecks = true }
                ) {
                    VStack(alignment: .leading, spacing: Metrics.pane - Metrics.spacingSmall) {
                        ForEach(WelcomeHighlight.all) { WelcomeHighlightRow(highlight: $0) }
                    }
                }
                .transition(.opacity)
            }
        }
        .frame(width: WelcomeView.contentWidth)
    }
}
#endif
