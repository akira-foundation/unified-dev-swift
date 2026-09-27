import SwiftUI
import Core

struct WelcomeView: View {
    let inspection: SetupInspection
    let registration: CommandLineRegistration
    let agentDefault: WelcomeAgentDefault
    let showsKeepAwake: Bool
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flow: OnboardingFlow
    @State private var subject: WelcomeCheckSubject?
    @State private var login: LoginTerminalSession?
    @State private var showsCommand = false

    init(
        inspection: SetupInspection,
        registration: CommandLineRegistration,
        agentDefault: WelcomeAgentDefault,
        start: OnboardingStep,
        showsKeepAwake: Bool = Machine.isPortable,
        onFinish: @escaping () -> Void
    ) {
        self.inspection = inspection
        self.registration = registration
        self.agentDefault = agentDefault
        self.showsKeepAwake = showsKeepAwake
        self.onFinish = onFinish
        _flow = State(initialValue: OnboardingFlow(step: start))
    }

    static let contentWidth: CGFloat = WelcomeMetrics.windowWidth

    private var report: SetupReport { inspection.shown }

    private var candidates: [AgentKind] { OnboardingAgentChoice.candidates(in: report) }

    private var offersAgentChoice: Bool {
        guard let hasDefaultPreset = agentDefault.hasDefaultPreset else { return false }
        return OnboardingAgentChoice.isOffered(
            in: report,
            hasCompletedOnboarding: WelcomeLaunch.hasCompletedBefore,
            hasDefaultPreset: hasDefaultPreset
        )
    }

    private var offersExtras: Bool { showsKeepAwake || registration.isOffered }

    var body: some View {
        ZStack(alignment: .top) {
            step
        }
        .frame(width: Self.contentWidth)
        .accessibilityIdentifier("welcome-step-\(flow.step.rawValue)")
        .onAppear {
            inspection.revealsInstantly = reduceMotion
            inspection.start()
            flow.offerAgentChoice(offersAgentChoice)
            flow.offerExtras(offersExtras)
        }
        .task { await agentDefault.loadPresets() }
        .onChange(of: offersAgentChoice) { _, offered in flow.offerAgentChoice(offered) }
        .onChange(of: offersExtras) { _, offered in flow.offerExtras(offered) }
        .onDisappear {
            stopLogin()
            inspection.cancel()
            registration.cancel()
            agentDefault.cancel()
        }
    }

    @ViewBuilder
    private var step: some View {
        switch flow.step {
        case .greeting:
            WelcomeGreetingStep(footer: footer, onSubmitPrompt: submitAPrompt)
                .transition(reduceMotion ? .identity : .opacity)
        case .checks:
            checksStep
        case .agent:
            WelcomeAgentStep(
                candidates: candidates,
                report: report,
                agentDefault: agentDefault,
                footer: footer
            )
            .transition(reduceMotion ? .identity : .opacity)
        case .extras:
            WelcomeExtrasStep(
                registration: registration,
                showsKeepAwake: showsKeepAwake,
                showsCommand: $showsCommand,
                footer: footer
            )
            .transition(reduceMotion ? .identity : .opacity)
        }
    }

    @ViewBuilder
    private var checksStep: some View {
        if let subject {
            WelcomeCheckDetailStep(subject: subject, session: login, footer: footer)
                .transition(reduceMotion ? .identity : .opacity)
        } else {
            WelcomeChecksStep(
                report: report,
                isRunning: inspection.isRunning,
                footer: footer,
                checkAgain: { inspection.start() },
                openDetail: openDetail
            )
            .transition(reduceMotion ? .identity : .opacity)
            .onAppear { inspection.presentChecks() }
            .onDisappear { inspection.dismissChecks() }
        }
    }

    private var footer: WelcomeFooter {
        WelcomeFooter(
            backTitle: flow.backButtonTitle,
            forwardTitle: flow.forwardButtonTitle,
            canGoBack: subject != nil || flow.canGoBack,
            isForwardEnabled: login?.isRunning != true,
            back: goBack,
            forward: goForward
        )
    }

    private func move(_ change: () -> Void) {
        withAnimation(reduceMotion ? nil : Motion.pane) { change() }
    }

    private func goBack() {
        move {
            guard subject == nil else {
                closeDetail()
                return
            }
            flow.goBack()
        }
    }

    private func goForward() {
        guard !flow.isLastStep else {
            finish()
            return
        }
        move {
            closeDetail()
            flow.advance()
        }
    }

    private func openDetail(_ check: SetupCheck) {
        guard let fix = check.fix else { return }
        stopLogin()
        move { subject = WelcomeCheckSubject(tool: check.tool, fix: fix) }
        guard fix.isInteractive else { return }
        login = Self.session(for: fix, onExit: { inspection.start() })
    }

    private func closeDetail() {
        stopLogin()
        subject = nil
    }

    private static func session(
        for fix: SetupFix,
        onExit: @escaping @MainActor () -> Void
    ) -> LoginTerminalSession? {
        let parts = (fix.command ?? "").split(separator: " ").map(String.init)
        guard let executable = parts.first else { return nil }
        return LoginTerminalSession(
            executable: executable,
            arguments: Array(parts.dropFirst()),
            directory: AgentScratchDirectory.current(),
            onExit: { _ in Task { @MainActor in onExit() } }
        )
    }

    private func stopLogin() {
        login?.stop()
        login = nil
    }

    private func finish() {
        stopLogin()
        WelcomeLaunch.recordCompletion()
        onFinish()
    }

    private func submitAPrompt() {
        stopLogin()
        onFinish()
        FeedbackPresenter.shared.open(.prompt)
    }
}
