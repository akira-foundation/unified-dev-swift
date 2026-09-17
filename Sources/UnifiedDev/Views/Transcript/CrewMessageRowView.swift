import SwiftUI
import Core

struct CrewMessageRowView: View {
    var message: CrewMessage

    var isWaiting = false

    @State private var showsEnvelope = false

    var body: some View {
        content.opacity(isWaiting ? TranscriptLayout.waitingOpacity : 1)
    }

    @ViewBuilder private var content: some View {
        switch message.event {
        case .said, .brief, .relayed: spoken
        case .stopped, .failed, .cancelled: fact
        }
    }

    private var spoken: some View {
        VStack(alignment: .leading, spacing: TranscriptLayout.tight) {
            header

            MarkdownView(message.text)
                .font(Typo.body)
                .proseLeading()
                .textSelection(.enabled)
                .frame(maxWidth: TranscriptLayout.proseMeasure, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if hasEnvelope { envelope }
        }
        .padding(.leading, TranscriptLayout.block)
        .overlay(alignment: .leading) { rule }
        .padding(.leading, TranscriptLayout.inset)
        .padding(.trailing, TranscriptLayout.inset)
        .padding(.vertical, TranscriptLayout.block)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: TranscriptLayout.tight) {
            Text(message.from)
                .font(Typo.code)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(verb)
                .font(Typo.label)
                .foregroundStyle(Palette.textTertiary)
                .lineLimit(1)
        }
        .textSelection(.enabled)
    }

    private var verb: String {
        switch message.event {
        case .said: "said"
        case .brief: "started you with"
        case .relayed: "said"
        case .stopped, .failed, .cancelled: ""
        }
    }

    private var hasEnvelope: Bool { message.sent != message.text }

    @ViewBuilder
    private var envelope: some View {
        VStack(alignment: .leading, spacing: TranscriptLayout.tight) {
            Button { showsEnvelope.toggle() } label: {
                HStack(spacing: TranscriptLayout.tight) {
                    Image(systemName: showsEnvelope ? "chevron.down" : "chevron.right")
                        .imageScale(.small)
                        .accessibilityHidden(true)

                    Text("What the model was handed")
                }
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if showsEnvelope {
                Text(message.sent)
                    .font(Typo.codeSmall)
                    .foregroundStyle(Palette.textSecondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, TranscriptLayout.tight)
    }

    private var fact: some View {
        Text(message.text)
            .font(Typo.label)
            .foregroundStyle(Palette.textSecondary)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: TranscriptLayout.proseMeasure, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, TranscriptLayout.inset)
            .padding(.vertical, TranscriptLayout.tight)
    }

    @ViewBuilder
    private var rule: some View {
        if let ink = CrewInk.rule(for: message.sender) {
            Rectangle()
                .fill(ink)
                .frame(width: TranscriptLayout.rule)
        }
    }
}

enum CrewInk {
    static func rule(for sender: CrewMessage.Sender) -> Color? {
        switch sender {
        case .orchestrator, .subagent: Palette.accent
        case .otherWorkspace: Palette.workspaceMessage
        case .unifieddev: nil
        }
    }
}
