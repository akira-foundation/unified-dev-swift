import SwiftUI
import Core

struct CheckRunRow: View {
    var run: CheckRun
    var isHovered = false
    var isSending = false
    var onSend: (@MainActor () -> Void)?

    @Environment(\.isOnEmphasizedSelection) private var isOnSelection

    var body: some View {
        Button(action: open) {
            HStack(spacing: InspectorLayout.gap) {
                glyph
                Text(run.name)
                    .font(Typo.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: Metrics.spacingSmall)
                if let onSend, isHovered || isSending {
                    send(onSend)
                }
                if let duration {
                    Text(duration)
                        .font(Typo.micro)
                        .monospacedDigit()
                        .foregroundStyle(Palette.textTertiary)
                }
                if run.detailsURL != nil {
                    Image(systemName: "arrow.up.right")
                        .font(Typo.micro)
                        .imageScale(.small)
                        .foregroundStyle(Palette.textTertiary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, InspectorLayout.gap)
            .frame(height: Metrics.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(run.detailsURL ?? run.name)
        .accessibilityInputLabels([run.name])
        .contextMenu {
            if let onSend {
                Button("Send This Failure to the Agent", action: onSend)
                    .disabled(isSending)
            }
        }
    }

    private func send(_ action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            Group {
                if isSending {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "text.bubble")
                        .font(Typo.micro)
                        .imageScale(.medium)
                        .foregroundStyle(isOnSelection ? Palette.selectedEmphasizedText : Palette.textSecondary)
                }
            }
            .frame(width: Metrics.glyph, height: Metrics.glyph)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSending)
        .help("Start a turn with this failure and its log")
        .accessibilityLabel("Send this failure to the agent")
    }

    private var glyph: some View {
        let state = CheckState(run)
        return Image(systemName: state.symbolName)
            .foregroundStyle(tint(ink(for: state)))
            .font(Typo.label)
            .imageScale(.medium)
            .frame(width: InspectorLayout.glyphWidth, height: InspectorLayout.glyphWidth, alignment: .leading)
            .accessibilityLabel(state.description)
    }

    private func ink(for state: CheckState) -> Color {
        switch state {
        case .queued, .running: Palette.warning
        case .passed: Palette.positive
        case .failed: Palette.negative
        case .skipped, .neutral: Palette.textTertiary
        }
    }

    private func tint(_ colour: Color) -> Color {
        isOnSelection ? Palette.selectedEmphasizedText : colour
    }

    private var duration: String? {
        guard let started = run.startedAt, let completed = run.completedAt else { return nil }
        let seconds = Int(completed.timeIntervalSince(started).rounded())
        guard seconds >= 0 else { return nil }
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m \(seconds % 60)s" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    private func open() {
        guard let url = run.detailsURL else { return }
        GitHubBridge.open(url)
    }
}
