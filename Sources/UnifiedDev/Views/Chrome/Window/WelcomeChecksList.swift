import SwiftUI
import Core

struct WelcomeChecksList: View {
    let report: SetupReport
    @Binding var expanded: SetupTool?
    @Binding var copied: SetupTool?
    @Binding var login: (tool: SetupTool, session: LoginTerminalSession)?
    let onLoginFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let gutter: CGFloat = 26

    var body: some View {
        checks(report)
    }

    private func checks(_ report: SetupReport) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(report.checks.enumerated()), id: \.element.id) { position, check in
                row(check, in: report, isLast: position == report.checks.count - 1)
                    .id(check.tool)
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
                }
                if login?.tool != check.tool, severity != .ok, check.outcome.isSettled {
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
                    .fill(check.outcome.isSettled ? Palette.accent(beside: [.warning]).opacity(0.35) : Palette.border)
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
                .controlSize(.mini)
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Palette.accent(beside: [.warning]))
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
                switch (fix.isInteractive, severity == .problem) {
                case (true, _):
                    Button(fix.summary) { startLogin(check, fix: fix) }
                        .controlSize(.small)
                case (false, true):
                    Text(fix.summary)
                        .font(Typo.label)
                        .foregroundStyle(Palette.textSecondary)
                case (false, false):
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
                    onLoginFinished()
                }
            }
        ) else { return }
        login = (check.tool, session)
    }

    private func stopLogin() {
        login?.session.stop()
        login = nil
    }
}
