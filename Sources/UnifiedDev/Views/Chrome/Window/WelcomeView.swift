import AppKit
import SwiftUI
import Core

struct WelcomeView: View {
    let inspection: SetupInspection
    let registration: CommandLineRegistration
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flow: OnboardingFlow
    @State private var expanded: SetupTool?
    @State private var copied: SetupTool?
    @State private var login: (tool: SetupTool, session: LoginTerminalSession)?

    init(
        inspection: SetupInspection,
        registration: CommandLineRegistration,
        start: OnboardingStep,
        onFinish: @escaping () -> Void
    ) {
        self.inspection = inspection
        self.registration = registration
        self.onFinish = onFinish
        _flow = State(initialValue: OnboardingFlow(step: start))
    }

    static let contentWidth: CGFloat = 520
    private static let width = contentWidth
    private static let markSize: CGFloat = 64
    private static let gutter: CGFloat = 26

    private var report: SetupReport { inspection.shown }

    private static let plinthTop: CGFloat = 30
    private static let plinthBottom: CGFloat = 22

    var body: some View {
        Group {
            switch flow.step {
            case .greeting:
                WelcomeGreeting(
                    isFirstVisit: flow.isFirstVisit(to: .greeting),
                    continueTitle: flow.forwardButtonTitle,
                    onContinue: { move { flow.advance() } }
                )
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
            checks(report)
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

    private func checks(_ report: SetupReport) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(report.checks.enumerated()), id: \.element.id) { position, check in
                row(check, in: report, isLast: position == report.checks.count - 1)
            }
        }
    }

    private func row(_ check: SetupCheck, in report: SetupReport, isLast: Bool) -> some View {
        let severity = report.severity(for: check.tool)
        let isOpen = expanded == check.tool || severity == .problem

        return HStack(alignment: .top, spacing: Metrics.spacingWide + Metrics.spacingTight) {
            soundingLine(check, severity: severity, isLast: isLast)

            VStack(alignment: .leading, spacing: Metrics.spacing) {
                HStack(alignment: .firstTextBaseline, spacing: Metrics.spacingWide) {
                    Text(check.tool.title)
                        .font(Typo.bodyEmphasis)
                        .foregroundStyle(Palette.textPrimary)

                    Spacer(minLength: Metrics.spacingWide)

                    status(check, in: report, severity: severity)
                }

                if let running = login, running.tool == check.tool {
                    loginTerminal(check, session: running.session)
                } else if severity != .ok, check.outcome.isSettled {
                    Text(check.tool.purpose)
                        .font(Typo.label)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let fix = check.fix {
                        fixStrip(check, fix: fix, severity: severity, isOpen: isOpen)
                    }
                }
            }
            .padding(.bottom, isLast ? 0 : Metrics.gutter + Metrics.spacingSmall)
        }
        .contentShape(.rect)
    }

    private func status(_ check: SetupCheck, in report: SetupReport, severity: SetupSeverity) -> some View {
        Group {
            switch check.outcome {
            case .pending:
                Text("Checking")
                    .font(Typo.label)
                    .foregroundStyle(Palette.textTertiary)
            case .ready(let detail):
                Text(detail ?? "Ready")
                    .font(detail == nil ? Typo.label : Typo.code)
                    .foregroundStyle(Palette.textTertiary)
            case .needsSignIn:
                Text(stateWord("Not signed in", in: report, severity: severity))
                    .font(Typo.label)
                    .foregroundStyle(severity == .problem ? Palette.warning : Palette.textTertiary)
            case .missing:
                Text(stateWord("Not installed", in: report, severity: severity))
                    .font(Typo.label)
                    .foregroundStyle(severity == .problem ? Palette.warning : Palette.textTertiary)
            }
        }
        .lineLimit(1)
        .truncationMode(.middle)
    }

    private func stateWord(_ state: String, in report: SetupReport, severity: SetupSeverity) -> String {
        severity == .note && report.isSettled ? "Optional, \(state.lowercased())" : state
    }

    private func soundingLine(_ check: SetupCheck, severity: SetupSeverity, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            glyph(check, severity: severity)
                .frame(width: Self.gutter, height: 17)

            if !isLast {
                Rectangle()
                    .fill(check.outcome.isSettled ? Palette.accent.opacity(0.35) : Palette.border)
                    .frame(width: Metrics.hairline)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: Self.gutter, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func glyph(_ check: SetupCheck, severity: SetupSeverity) -> some View {
        switch check.outcome {
        case .pending:
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.7)
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Palette.accent)
                .font(.system(size: 15))
                .transition(reduceMotion ? .identity : .scale(scale: 0.6).combined(with: .opacity))
        case .needsSignIn:
            Image(systemName: severity == .problem ? "lock.circle.fill" : "lock.circle")
                .foregroundStyle(severity == .problem ? Palette.warning : Palette.textTertiary)
                .font(.system(size: 15))
                .transition(reduceMotion ? .identity : .scale(scale: 0.6).combined(with: .opacity))
        case .missing:
            Image(systemName: severity == .problem ? "exclamationmark.circle.fill" : "circle.dotted")
                .foregroundStyle(severity == .problem ? Palette.warning : Palette.textTertiary)
                .font(.system(size: 15))
                .transition(reduceMotion ? .identity : .scale(scale: 0.6).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func fixStrip(
        _ check: SetupCheck,
        fix: SetupFix,
        severity: SetupSeverity,
        isOpen: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacingWide) {
            HStack(spacing: Metrics.inset) {
                if fix.isInteractive {
                    Button(fix.summary) { startLogin(check, fix: fix) }
                        .controlSize(.small)
                } else if severity == .problem {
                    Text(fix.summary)
                        .font(Typo.label)
                        .foregroundStyle(Palette.textSecondary)
                } else {
                    Button(isOpen ? "Hide the install command" : "Show the install command") {
                        withAnimation(reduceMotion ? nil : Motion.pane) {
                            expanded = isOpen ? nil : check.tool
                        }
                    }
                    .controlSize(.small)
                }

                if let url = fix.url {
                    Link("Instructions", destination: url)
                        .font(Typo.label)
                        .foregroundStyle(Palette.link)
                }

                Spacer(minLength: 0)
            }

            if isOpen, let command = fix.command {
                commandLine(check, command: command)
            }
        }
    }

    private func commandLine(_ check: SetupCheck, command: String) -> some View {
        HStack(spacing: Metrics.spacingWide) {
            Text(command)
                .font(Typo.code)
                .foregroundStyle(Palette.textPrimary)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: Metrics.spacing)

            Button(copied == check.tool ? "Copied" : "Copy") {
                Clipboard.copy(command)
                copied = check.tool
                Task {
                    try? await Task.sleep(for: Clipboard.flashDuration)
                    if copied == check.tool { copied = nil }
                }
            }
            .buttonStyle(.glass)
            .font(Typo.label)
            .foregroundStyle(Palette.link)
        }
        .padding(.horizontal, Metrics.inset)
        .padding(.vertical, Metrics.spacingWide)
        .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Metrics.corner))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.corner)
                .strokeBorder(Palette.border, lineWidth: Metrics.outline)
        )
        .transition(reduceMotion ? .identity : .opacity)
    }

    private func loginTerminal(_ check: SetupCheck, session: LoginTerminalSession) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Metrics.spacingWide) {
                Text(session.isRunning ? "Running \(session.label)" : "\(session.label) finished")
                    .font(Typo.code)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Button("Back to the checks", systemImage: "chevron.left") { stopLogin() }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .font(Typo.label)
                    .foregroundStyle(Palette.link)
                    .help(session.isRunning ? "Stop this and go back to the list" : "Go back to the list")
            }
            .padding(.horizontal, Metrics.inset)
            .frame(height: Metrics.barHeight)
            .background(Palette.surfaceSunken)

            Hairline()

            LoginTerminal(session: session)
                .frame(height: 220)
        }
        .clipShape(RoundedRectangle(cornerRadius: Metrics.corner))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.corner)
                .strokeBorder(Palette.border, lineWidth: Metrics.outline)
        )
    }

    private func startLogin(_ check: SetupCheck, fix: SetupFix) {
        stopLogin()
        let parts = (fix.command ?? "").split(separator: " ").map(String.init)
        guard let executable = parts.first else { return }
        guard let session = LoginTerminalSession(
            executable: executable,
            arguments: Array(parts.dropFirst()),
            directory: AgentScratchDirectory.current(),
            onExit: { _ in
                Task { @MainActor in
                    inspection.start()
                }
            }
        ) else { return }
        login = (check.tool, session)
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
