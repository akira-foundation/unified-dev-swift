import AppKit
import Core
import Observation
import SwiftUI

#if DEBUG
@MainActor
enum WelcomeLayoutProbe {
    static var isRequested: Bool { CommandLine.arguments.contains("--welcome-layout-probe") }

    private static let footerReach: CGFloat = 96
    private static let rightReach: CGFloat = 48
    private static let centreSlack: CGFloat = 2
    private static let leastParts = 6

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
        var extrasHeight: CGFloat = 0

        for disableAnimations in [false, true] {
            let fixture = WelcomeLayoutFixture(
                showsKeepAwake: true,
                registration: .rehearsed(offering: rehearsedAddCommand())
            )
            let (window, host) = hosted(WelcomeLayoutContent(fixture: fixture), disableAnimations: disableAnimations)
            await settle(window)
            greetingHeight = window.frame.height

            for visit in 0..<3 {
                withAnimation(disableAnimations ? nil : Motion.pane) { fixture.stage = .extras }
                await settle(window)
                extrasHeight = window.frame.height
                check(extrasHeight > greetingHeight, "the extras step did not grow the window")
                check(abs(host.view.bounds.height - host.fittingContentSize().height) < 1,
                      "the extras step does not fit the window")
                check(!window.isVisible && !window.isKeyWindow, "probe showed its window")
                if disableAnimations, visit == 2 {
                    report(on: window, titled: WelcomeExtrasStep.title, named: "the extras step", check: check)
                }
                withAnimation(disableAnimations ? nil : Motion.pane) { fixture.stage = .greeting }
                await settle(window)
                check(abs(window.frame.height - greetingHeight) < 1,
                      "visit \(visit), animations disabled \(disableAnimations): greeting \(greetingHeight), returned \(window.frame.height), ideal \(host.fittingContentSize().height)")
                if disableAnimations, visit == 2 {
                    report(on: window, titled: WelcomeGreetingStep.title, named: "the greeting", check: check)
                }
            }
            window.contentViewController = nil
        }

        let session = LoginTerminalSession(
            executable: "git", arguments: ["--version"],
            directory: NSTemporaryDirectory(), onExit: { _ in }
        )
        check(session != nil, "the probe could not open a login terminal")
        let tallest = WelcomeLayoutFixture(
            showsKeepAwake: true,
            registration: .rehearsed(offering: rehearsedAddCommand()),
            session: session
        )
        tallest.stage = .detail
        let (detailWindow, detailHost) = hosted(WelcomeLayoutContent(fixture: tallest), disableAnimations: true)
        await settle(detailWindow)
        await settle(detailWindow)
        let tallestHeight = detailWindow.frame.height
        check(abs(detailHost.view.bounds.height - detailHost.fittingContentSize().height) < 1,
              "the login detail does not fit the window")
        check(!detailWindow.isVisible && !detailWindow.isKeyWindow, "probe showed its window")
        check(tallestHeight <= WelcomeSheetFit.shortestLaptopVisibleHeight,
              "the tallest window is \(tallestHeight)pt, past the \(WelcomeSheetFit.shortestLaptopVisibleHeight)pt a 900 point laptop display leaves visible")
        report(on: detailWindow, titled: SetupTool.gitHub.title, named: "the login detail", check: check)
        session?.stop()
        detailWindow.contentViewController = nil

        let inspection = SetupInspection(rehearsal: SetupRehearsal.report)
        let live = WelcomeView(
            inspection: inspection,
            registration: .rehearsed(offering: rehearsedAddCommand()),
            agentDefault: WelcomeAgentDefault(store: { nil }),
            start: .checks,
            showsKeepAwake: true,
            onFinish: {}
        )
        let (checksWindow, checksHost) = hosted(live, disableAnimations: true)
        await settle(checksWindow)
        await settle(checksWindow)
        let checksHeight = checksWindow.frame.height
        check(abs(checksHost.view.bounds.height - checksHost.fittingContentSize().height) < 1,
              "the checks step does not fit the window")
        check(checksHeight <= WelcomeSheetFit.shortestLaptopVisibleHeight,
              "the checks window is \(checksHeight)pt, past the \(WelcomeSheetFit.shortestLaptopVisibleHeight)pt a 900 point laptop display leaves visible")
        report(on: checksWindow, titled: SetupRehearsal.report?.headline ?? "", named: "the checks step", check: check)
        inspection.cancel()
        checksWindow.contentViewController = nil

        let result: JSONValue = .object([
            "checks": .integer(checks), "passed": .bool(failures.isEmpty),
            "width": .number(Double(WelcomeView.contentWidth)),
            "greeting": .number(Double(greetingHeight)),
            "extras": .number(Double(extrasHeight)),
            "loginDetail": .number(Double(tallestHeight)),
            "checksStep": .number(Double(checksHeight)),
            "heightLimit": .number(Double(WelcomeSheetFit.defaultHeightLimit)),
            "laptopVisible": .number(Double(WelcomeSheetFit.shortestLaptopVisibleHeight)),
            "failures": .strings(failures),
        ])
        if let data = try? JSONEncoder().encode(result) { FileHandle.standardOutput.write(data) }
        exit(failures.isEmpty ? 0 : 1)
    }

    private static func report(
        on window: NSWindow,
        titled headline: String,
        named subject: String,
        check: (Bool, String) -> Void
    ) {
        guard let drawn = WelcomeDrawn.stages[headline], let stage = drawn["stage"] else {
            check(false, "\(subject) reported no drawn stage")
            return
        }
        check(drawn.count >= leastParts,
              "\(subject) reported \(drawn.count) drawn parts, too few to assert anything about")
        let content = window.contentRect(forFrameRect: window.frame)
        check(abs(stage.height + WelcomeSheetFit.titleBarHeight - content.height) < 1,
              "\(subject) drew a \(stage.height)pt stage under a \(WelcomeSheetFit.titleBarHeight)pt title bar in a \(content.height)pt content view")
        check(abs(stage.width - WelcomeView.contentWidth) < 1,
              "\(subject) drew a \(stage.width)pt wide stage, not \(WelcomeView.contentWidth)pt")

        let room = CGRect(origin: .zero, size: stage.size).insetBy(dx: -1, dy: -1)
        let outside = drawn
            .filter { $0.key != "stage" && !room.contains($0.value) }
            .map { "\($0.key) at \($0.value.integral)" }
            .sorted()
        check(outside.isEmpty,
              "\(subject) draws outside its own frame: \(outside.joined(separator: ", "))")

        guard let back = drawn["back"], let forward = drawn["forward"] else {
            check(false, "\(subject) drew no Back and Continue")
            return
        }
        check(back.maxX <= forward.minX + centreSlack, "\(subject) puts Back to the right of Continue")
        if let dots = drawn["dots"] {
            check(dots.maxX <= back.minX, "\(subject) puts its progress dots to the right of Back")
            check(dots.minX - stage.minX <= rightReach,
                  "\(subject) leaves the progress dots \(dots.minX - stage.minX)pt from the left edge")
            check(stage.maxY - dots.maxY <= footerReach, "\(subject) does not put the progress dots in the footer")
        } else {
            check(false, "\(subject) drew no progress dots")
        }
        check(stage.maxX - forward.maxX <= rightReach,
              "\(subject) leaves Continue \(stage.maxX - forward.maxX)pt from the right edge")
        check(stage.maxY - forward.maxY <= footerReach,
              "\(subject) leaves Continue \(stage.maxY - forward.maxY)pt above the bottom edge")
        check(stage.maxY - back.maxY <= footerReach, "\(subject) does not put Back in the footer")

        guard let title = drawn["title"], let body = drawn["body"] else {
            check(false, "\(subject) drew no title and no body")
            return
        }
        check(abs(title.midX - stage.midX) <= centreSlack, "\(subject) does not centre its title")
        check(title.maxY <= stage.height / 2, "\(subject) does not put its title above the middle")
        check(abs(body.midX - stage.midX) <= centreSlack, "\(subject) does not centre its body column")
        check(body.width <= WelcomeMetrics.column + 1,
              "\(subject) draws a \(body.width)pt body column, wider than the \(WelcomeMetrics.column)pt it asks for")
        if let link = drawn["link"] {
            check(abs(link.midX - stage.midX) <= centreSlack, "\(subject) does not centre its link")
            check(link.maxY <= back.minY, "\(subject) puts its link below the footer")
        }
    }

    private static func hosted(
        _ rootView: some View,
        disableAnimations: Bool
    ) -> (NSWindow, WelcomeHostingController) {
        let host = WelcomeHostingController(
            rootView: rootView
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

private enum WelcomeLayoutStage {
    case greeting
    case extras
    case detail
}

@MainActor
@Observable
private final class WelcomeLayoutFixture {
    var stage: WelcomeLayoutStage = .greeting
    var showsCommand = true
    let registration: CommandLineRegistration
    let showsKeepAwake: Bool
    let session: LoginTerminalSession?

    init(
        showsKeepAwake: Bool = false,
        registration: CommandLineRegistration = CommandLineRegistration(source: { nil }),
        session: LoginTerminalSession? = nil
    ) {
        self.showsKeepAwake = showsKeepAwake
        self.registration = registration
        self.session = session
    }
}

private struct WelcomeLayoutContent: View {
    let fixture: WelcomeLayoutFixture

    private static let subject = WelcomeCheckSubject(
        tool: .gitHub,
        fix: SetupFix(summary: "Sign in to GitHub", command: "gh auth login", isInteractive: true)
    )

    var body: some View {
        Group {
            switch fixture.stage {
            case .greeting:
                WelcomeGreetingStep(footer: footer, onSubmitPrompt: {})
            case .extras:
                WelcomeExtrasStep(
                    registration: fixture.registration,
                    showsKeepAwake: fixture.showsKeepAwake,
                    showsCommand: Binding(
                        get: { fixture.showsCommand },
                        set: { shown in MainActor.assumeIsolated { fixture.showsCommand = shown } }
                    ),
                    footer: footer
                )
            case .detail:
                WelcomeCheckDetailStep(subject: Self.subject, session: fixture.session, footer: footer)
            }
        }
        .frame(width: WelcomeView.contentWidth)
        .transition(.opacity)
    }

    private var footer: WelcomeFooter {
        WelcomeFooter(
            backTitle: OnboardingFlow.backTitle,
            forwardTitle: fixture.stage == .greeting ? OnboardingFlow.startTitle : OnboardingFlow.forwardTitle,
            progress: OnboardingProgress(position: fixture.stage == .greeting ? 1 : 3, count: 4),
            canGoBack: fixture.stage != .greeting,
            back: {},
            forward: {}
        )
    }
}
#endif
