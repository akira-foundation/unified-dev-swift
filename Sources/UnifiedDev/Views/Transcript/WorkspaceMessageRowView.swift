import SwiftUI
import Core

struct WorkspaceMessageRowView: View {
    var message: CrewMessage
    var isWaiting = false
    var holdSentence: String?
    var onDelete: () -> Void = {}

    @Environment(AppModel.self) private var app
    @Environment(\.transcriptBubbleWidth) private var bubbleWidth

    @State private var showsEnvelope = false
    @State private var isPointedAt = false

    private static let dots = StrokeStyle(lineWidth: Metrics.outline, dash: [2, 3])

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: UserTurnRowView.inset)

            VStack(alignment: .trailing, spacing: TranscriptLayout.tight) {
                WorkspaceMessageOrigin(end: message.route, direction: .from)
                bubble
                caption
                if showsEnvelope { envelope }
            }
        }
        .padding(.horizontal, TranscriptLayout.inset)
        .padding(.vertical, TranscriptLayout.inset)
        .onHover { isPointedAt = $0 }
    }

    private var bubble: some View {
        CappedWidth(width: bubbleWidth?.cap ?? UserTurnRowView.uncappedFallback) {
            Text(message.text)
                .font(Typo.body)
                .foregroundStyle(isWaiting ? Palette.textSecondary : Palette.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(UserTurnRowView.padding)
        }
        .padding(.bottom, OutgoingBubbleShape.tailDrop)
        .background {
            if isWaiting {
                OutgoingBubbleShape(cornerRadius: UserTurnRowView.corner)
                    .strokeBorder(Palette.workspaceMessage, style: Self.dots)
            } else {
                OutgoingBubbleShape(cornerRadius: UserTurnRowView.corner)
                    .fill(Palette.workspaceMessageFill)
            }
        }
    }

    @ViewBuilder
    private var caption: some View {
        HStack(spacing: Metrics.gutter) {
            if isWaiting {
                if let holdSentence {
                    Text(holdSentence).foregroundStyle(Palette.textTertiary)
                }
                Button("Delete", action: onDelete)
                    .buttonStyle(.plain)
                    .foregroundStyle(isPointedAt ? Palette.link : Palette.textTertiary)
                    .pointerStyle(.link)
                    .help("Takes this message back out of the queue. It is not sent, and the workspace that sent it is told.")
            } else {
                if let route = message.route, route.workspaceID != nil {
                    Button("Open \(route.workspace)") { app.revealWorkspace(route.workspaceID) }
                        .buttonStyle(.plain)
                        .foregroundStyle(Palette.workspaceMessage)
                        .pointerStyle(.link)
                }
                Button(showsEnvelope ? "Hide what the model was handed" : "What the model was handed") {
                    showsEnvelope.toggle()
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.textTertiary)
                .pointerStyle(.link)
            }
        }
        .font(Typo.caption)
    }

    private var envelope: some View {
        Text(message.sent)
            .font(Typo.codeSmall)
            .foregroundStyle(Palette.textSecondary)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: bubbleWidth?.cap ?? UserTurnRowView.uncappedFallback, alignment: .leading)
    }
}
