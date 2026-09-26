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
    @State private var expanded: SetupTool?
    @State private var copied: SetupTool?
    @State private var login: (tool: SetupTool, session: LoginTerminalSession)?

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

    static let contentWidth: CGFloat = 520
    private static let width = contentWidth

    private var report: SetupReport { inspection.shown }

    var body: some View {
        ZStack(alignment: .top) {
            switch flow.step {
            case .greeting:
                greetingSheet
            case .checks:
                checksStep
            }
        }
        .frame(width: Self.width)
        .background(Palette.surface)
        .accessibilityIdentifier("welcome-step-\(flow.step.rawValue)")
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
        WelcomeSheet(
            title: report.headline,
            subtitle: report.sentence,
            actionTitle: primary.title,
            action: { perform(primary.action) },
            secondary: { checksSecondary }
        ) {
            VStack(alignment: .leading, spacing: Metrics.pane) {
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

                WelcomeOffers(
                    registration: registration,
                    showsKeepAwake: showsKeepAwake,
                    onSubmitPrompt: submitAPrompt
                )
            }
        }
        .transition(reduceMotion ? .identity : .opacity)
        .onAppear { inspection.presentChecks() }
        .onDisappear { inspection.dismissChecks() }
    }

    private var primary: OnboardingPrimary {
        OnboardingPrimary(step: flow.step, verdict: inspection.truth.verdict)
    }

    private var checksSecondary: some View {
        HStack(spacing: Metrics.inset) {
            if let title = flow.backButtonTitle {
                Button(title, systemImage: "chevron.left") { move { stopLogin(); flow.goBack() } }
                    .buttonStyle(.glass)
                    .font(Typo.body)
                    .foregroundStyle(Palette.link)
            }

            Spacer(minLength: Metrics.inset)

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
    }

    private func stopLogin() {
        login?.session.stop()
        login = nil
    }

    private func perform(_ action: OnboardingPrimary.Action) {
        switch action {
        case .checkAgain:
            inspection.start()
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
        stopLogin()
        onFinish()
        FeedbackPresenter.shared.open(.prompt)
    }
}
