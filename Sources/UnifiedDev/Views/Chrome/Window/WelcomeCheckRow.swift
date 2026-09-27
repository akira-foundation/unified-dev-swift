import SwiftUI
import Core

struct WelcomeCheckRow: View {
    let check: SetupCheck
    let severity: SetupSeverity
    let isSettled: Bool
    let openDetail: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let glyphColumn: CGFloat = 22
    private static let glyphSize: CGFloat = 16

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.inset + Metrics.spacingSmall) {
            glyph
                .frame(width: Self.glyphColumn, alignment: .center)
                .accessibilityHidden(true)

            Text(check.tool.title)
                .font(Typo.bodyEmphasis)
                .foregroundStyle(Palette.textPrimary)

            Spacer(minLength: Metrics.inset)

            status
                .lineLimit(1)
                .truncationMode(.middle)

            if let fix = check.fix {
                Button(Self.openTitle(for: fix)) { openDetail() }
                    .buttonStyle(.plain)
                    .font(Typo.label)
                    .foregroundStyle(Palette.link)
                    .accessibilityIdentifier("welcome-check-open-\(check.tool.rawValue)")
            }
        }
        .contentShape(.rect)
    }

    static func openTitle(for fix: SetupFix) -> String {
        fix.isInteractive ? "Sign in…" : "Install…"
    }

    @ViewBuilder
    private var glyph: some View {
        switch check.outcome {
        case .pending:
            ProgressView()
                .controlSize(.mini)
        case .ready:
            mark("checkmark.circle.fill", ink: Palette.accent(beside: [.warning]))
        case .needsSignIn:
            mark(severity == .problem ? "lock.circle.fill" : "lock.circle", ink: stateInk)
        case .missing:
            mark(severity == .problem ? "exclamationmark.circle.fill" : "circle.dotted", ink: stateInk)
        }
    }

    private func mark(_ name: String, ink: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: Self.glyphSize))
            .foregroundStyle(ink)
            .transition(reduceMotion ? .identity : .scale(scale: 0.6).combined(with: .opacity))
    }

    private var stateInk: Color {
        severity == .problem ? Palette.warning : Palette.textTertiary
    }

    @ViewBuilder
    private var status: some View {
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
            Text(stateWord("Not signed in"))
                .font(Typo.label)
                .foregroundStyle(stateInk)
        case .missing:
            Text(stateWord("Not installed"))
                .font(Typo.label)
                .foregroundStyle(stateInk)
        }
    }

    private func stateWord(_ state: String) -> String {
        severity == .note && isSettled ? "Optional, \(state.lowercased())" : state
    }
}
