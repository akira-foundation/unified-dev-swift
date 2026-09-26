import AppKit
import SwiftUI
import Core

struct WelcomeView: View {
    let inspection: SetupInspection
    let registration: CommandLineRegistration
    let agentDefault: WelcomeAgentDefault
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flow: OnboardingFlow
    @State private var expanded: SetupTool?
    @State private var copied: SetupTool?
    @State private var login: (tool: SetupTool, session: LoginTerminalSession)?

    init(
        inspection: SetupInspection,
        registration: CommandLineRegistration,
        agentDefault: WelcomeAgentDefault,
        start: OnboardingStep,
        onFinish: @escaping () -> Void
    ) {
        self.inspection = inspection
        self.registration = registration
        self.agentDefault = agentDefault
        self.onFinish = onFinish
        _flow = State(initialValue: OnboardingFlow(step: start))
    }

    static let contentWidth: CGFloat = 520
    private static let width = contentWidth
    private static let markSize: CGFloat = 64

    private var report: SetupReport { inspection.shown }

    private static let plinthTop: CGFloat = 30
    private static let plinthBottom: CGFloat = 22

    var body: some View {
        ZStack(alignment: .top) {
            switch flow.step {
            case .greeting:
                greetingSheet
            case .checks:
                checksStep
            case .keepAwake:
                keepAwakeStep
            case .commandLine:
                commandLineStep
            case .promptSubmission:
                promptStep
            }
        }
        .frame(width: Self.width)
        .background(Palette.surface)
        .accessibilityIdentifier("welcome-step-\(flow.step.rawValue)")
        .onChange(of: registration.isOffered, initial: true) { _, isOffered in
            flow.offerCommandLine(isOffered)
        }
        .onAppear {
            flow.offerKeepAwake(Machine.isPortable && SleepSwitch.shared.standing != .ready)
        }
        .onAppear {
            inspection.revealsInstantly = reduceMotion
            inspection.start()
        }
        .onDisappear {
            login?.session.stop()
            inspection.cancel()
            registration.cancel()
        }
    }

    private func move(_ change: () -> Void) {
        withAnimation(reduceMotion ? nil : Motion.pane) { change() }
    }

    private var greetingSheet: some View {
        WelcomeSheet(
            title: "Welcome to Unified Dev",
            subtitle: "A worktree, an agent and a branch for every task you describe",
            actionTitle: OnboardingFlow.startTitle,
            action: { move { flow.advance() } }
        ) {
            VStack(alignment: .leading, spacing: Metrics.pane - Metrics.spacingSmall) {
                ForEach(WelcomeHighlight.all) { highlight in
                    WelcomeHighlightRow(highlight: highlight)
                }
            }
        }
        .transition(reduceMotion ? .identity : .opacity)
    }

    private var checksStep: some View {
        VStack(spacing: 0) {
            plinth
            hairline
            body(report)
            hairline
            footer
        }
        .transition(reduceMotion ? .identity : .opacity)
        .onAppear { inspection.presentChecks() }
        .onDisappear { inspection.dismissChecks() }
    }

    private var keepAwakeStep: some View {
        VStack(spacing: 0) {
            plinth
            hairline
            WelcomeKeepAwake()
            hairline
            footer
        }
        .transition(reduceMotion ? .identity : .opacity)
    }

    private var commandLineStep: some View {
        VStack(spacing: 0) {
            plinth
            hairline
            if let command = registration.command {
                WelcomeCommandLine(command: command)
            }
            hairline
            footer
        }
        .transition(reduceMotion ? .identity : .opacity)
    }

    private var promptStep: some View {
        VStack(spacing: 0) {
            plinth
            hairline
            WelcomePromptSubmission(onSubmit: submitAPrompt)
            hairline
            footer
        }
        .transition(reduceMotion ? .identity : .opacity)
    }

    private var hairline: some View {
        Rectangle().fill(Palette.border).frame(height: Metrics.hairline)
    }

    private var plinth: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: Self.markSize, height: Self.markSize)
                .shadow(color: .black.opacity(0.55), radius: 14, y: 8)
                .accessibilityHidden(true)

            Text(verbatim: "Welcome to Unified Dev")
                .font(Typo.display)
                .tracking(Typo.displayTracking)
                .foregroundStyle(Palette.textPrimary)
                .padding(.top, Metrics.spacingWide + Metrics.spacingSmall)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Self.plinthTop)
        .padding(.bottom, Self.plinthBottom)
        .padding(.horizontal, Metrics.pane)
        .background {
            Palette.surface
                .ignoresSafeArea(edges: .top)
        }
    }

    private func body(_ report: SetupReport) -> some View {
        VStack(alignment: .leading, spacing: Metrics.pane - Metrics.spacingSmall) {
            verdict(report)
            WelcomeChecksList(
                report: report,
                expanded: $expanded,
                copied: $copied,
                login: $login,
                onLoginFinished: { inspection.start() }
            )
            if OnboardingAgentChoice.isOffered(
                in: report, hasCompletedOnboarding: WelcomeLaunch.hasCompletedBefore
            ) {
                WelcomeAgentChoice(
                    candidates: OnboardingAgentChoice.candidates(in: report),
                    agentDefault: agentDefault
                )
                .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .padding(Metrics.pane)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func verdict(_ report: SetupReport) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            Text(report.headline)
                .font(Typo.displayHeading)
                .foregroundStyle(Palette.textPrimary)

            Text(report.sentence)
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .id(report.verdict)
        .transition(reduceMotion ? .identity : .opacity)
        .animation(reduceMotion ? nil : Motion.arrival, value: report.verdict)
    }

    private func stopLogin() {
        login?.session.stop()
        login = nil
    }

    private var footer: some View {
        let primary = OnboardingPrimary(
            step: flow.step,
            verdict: inspection.truth.verdict,
            next: flow.next
        )

        return HStack(spacing: Metrics.inset) {
            if let title = flow.backButtonTitle {
                Button(title, systemImage: "chevron.left") { move { stopLogin(); flow.goBack() } }
                    .buttonStyle(.glass)
                    .font(Typo.body)
                    .foregroundStyle(Palette.link)
            }

            WelcomeProgressDots(
                progress: flow.progress,
                leadingInset: flow.canGoBack ? Metrics.inset : 0
            )

            Spacer(minLength: Metrics.inset)

            if flow.step == .checks {
                if inspection.truth.verdict == .blocked {
                    Button("Skip for now") { finish() }
                        .buttonStyle(.glass)
                        .font(Typo.body)
                        .foregroundStyle(Palette.link)
                } else {
                    Button("Check again") { inspection.start() }
                        .buttonStyle(.glass)
                        .font(Typo.body)
                        .foregroundStyle(inspection.isRunning ? Palette.textTertiary : Palette.link)
                        .disabled(inspection.isRunning)
                }
            }

            Button(primary.title) { perform(primary.action) }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(Palette.controlAccent)
                .controlSize(.large)
        }
        .padding(.horizontal, Metrics.pane)
        .padding(.vertical, Metrics.inset + Metrics.spacingSmall)
        .background(Palette.surfaceSunken)
    }

    private func perform(_ action: OnboardingPrimary.Action) {
        switch action {
        case .checkAgain:
            inspection.start()
        case .advance:
            move { stopLogin(); flow.advance() }
        case .finish:
            finish()
        }
    }

    private func finish() {
        stopLogin()
        WelcomeLaunch.recordCompletion()
        onFinish()
    }

    private func submitAPrompt() {
        finish()
        FeedbackPresenter.shared.open(.prompt)
    }
}
