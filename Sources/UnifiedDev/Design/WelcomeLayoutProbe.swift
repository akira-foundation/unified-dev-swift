import AppKit
import Core
import Observation
import SwiftUI

#if DEBUG
@MainActor
enum WelcomeLayoutProbe {
    static var isRequested: Bool { CommandLine.arguments.contains("--welcome-layout-probe") }

    private static let offersGrowth: CGFloat = 150

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
        var greetingHeight: CGFloat = 0
        var checksHeight: CGFloat = 0

        for disableAnimations in [false, true] {
            let fixture = WelcomeLayoutFixture()
            let (window, host) = hosted(fixture, disableAnimations: disableAnimations)
            await settle(window)
            greetingHeight = window.frame.height

            for visit in 0..<3 {
                withAnimation(disableAnimations ? nil : Motion.pane) { fixture.showsChecks = true }
                await settle(window)
                checksHeight = window.frame.height
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

        let tallest = WelcomeLayoutFixture(
            showsKeepAwake: true,
            registration: .rehearsed(offering: rehearsedAddCommand())
        )
        tallest.showsChecks = true
        let (window, host) = hosted(tallest, disableAnimations: true)
        await settle(window)
        await settle(window)
        let tallestHeight = window.frame.height
        let tallestContent = host.fittingContentSize().height
        check(abs(host.view.bounds.height - tallestContent) < 1,
              "the tallest sheet does not fit the window")
        check(!window.isVisible && !window.isKeyWindow, "probe showed its window")
        check(tallestHeight <= WelcomeSheetFit.shortestLaptopVisibleHeight,
              "the tallest window is \(tallestHeight)pt, past the \(WelcomeSheetFit.shortestLaptopVisibleHeight)pt a 900 point laptop display leaves visible")
        let hidden = hiddenByScrolling(in: host.view)
        check(hidden != nil, "the tallest sheet drew no scroll view")
        check((hidden ?? 0) > offersGrowth,
              "the tallest sheet keeps \(hidden ?? 0)pt out of sight, too little for a keep awake row and a command block")
        window.contentViewController = nil

        let result: JSONValue = .object([
            "checks": .integer(checks), "passed": .bool(failures.isEmpty),
            "greeting": .number(Double(greetingHeight)),
            "checksSheet": .number(Double(checksHeight)),
            "tallestSheet": .number(Double(tallestHeight)),
            "tallestHidden": .number(Double(hidden ?? 0)),
            "heightLimit": .number(Double(WelcomeSheetFit.defaultHeightLimit)),
            "laptopVisible": .number(Double(WelcomeSheetFit.shortestLaptopVisibleHeight)),
            "failures": .strings(failures),
        ])
        if let data = try? JSONEncoder().encode(result) { FileHandle.standardOutput.write(data) }
        exit(failures.isEmpty ? 0 : 1)
    }

    private static func hosted(
        _ fixture: WelcomeLayoutFixture,
        disableAnimations: Bool
    ) -> (NSWindow, WelcomeHostingController) {
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
        return (window, host)
    }

    private static func hiddenByScrolling(in view: NSView) -> CGFloat? {
        if let scroll = view as? NSScrollView, let document = scroll.documentView {
            return document.bounds.height - scroll.contentView.bounds.height
        }
        for subview in view.subviews {
            if let hidden = hiddenByScrolling(in: subview) { return hidden }
        }
        return nil
    }

    private static func rehearsedAddCommand() -> String {
        let socket = (try? BridgeSocketPath.derive(databasePath: Bundle.main.bundlePath)) ?? ""
        return BridgeRegistration.ownerAddCommand(BridgeAttachment(
            shimPath: (Bundle.main.bundlePath as NSString).appendingPathComponent("Contents/MacOS/bridge"),
            socketPath: socket,
            token: String(repeating: "9f", count: 32),
            role: .owner
        ))
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
    let registration: CommandLineRegistration
    let showsKeepAwake: Bool
    let agentDefault = WelcomeAgentDefault(store: { nil })

    init(
        showsKeepAwake: Bool = false,
        registration: CommandLineRegistration = CommandLineRegistration(source: { nil })
    ) {
        self.showsKeepAwake = showsKeepAwake
        self.registration = registration
    }
}

private struct WelcomeLayoutContent: View {
    let fixture: WelcomeLayoutFixture

    var body: some View {
        Group {
            if fixture.showsChecks {
                welcome(start: .checks)
            } else {
                welcome(start: .greeting)
            }
        }
        .frame(width: WelcomeView.contentWidth)
    }

    private func welcome(start: OnboardingStep) -> some View {
        WelcomeView(
            inspection: fixture.inspection,
            registration: fixture.registration,
            agentDefault: fixture.agentDefault,
            start: start,
            showsKeepAwake: fixture.showsKeepAwake,
            onFinish: {}
        )
        .transition(.opacity)
    }
}
#endif
