import SwiftUI
import Core

struct WorkspaceMessageSentRowView: View {
    var record: WorkspaceSayRecord

    @Environment(AppModel.self) private var app
    @Environment(\.transcriptBubbleWidth) private var bubbleWidth

    @State private var message: WorkspaceMessage?
    @State private var isCancelling = false

    private static let dots = StrokeStyle(lineWidth: Metrics.outline, dash: [2, 3])

    private var isQueued: Bool { message?.state == .queued }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: TranscriptLayout.tight) {
                WorkspaceMessageOrigin(end: record.target, direction: .to)
                bubble
                status
            }

            Spacer(minLength: UserTurnRowView.inset)
        }
        .padding(.vertical, TranscriptLayout.inset)
        .task(id: app.workspaceMessagesRevision) {
            let read = await app.workspaceMessage(id: record.messageID)
            guard !Task.isCancelled, read != message else { return }
            message = read
        }
    }

    private var bubble: some View {
        CappedWidth(width: bubbleWidth?.cap ?? UserTurnRowView.uncappedFallback) {
            Text(record.text)
                .font(Typo.body)
                .foregroundStyle(isQueued ? Palette.textSecondary : Palette.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(UserTurnRowView.padding)
        }
        .padding(.bottom, OutgoingBubbleShape.tailDrop)
        .background {
            ZStack {
                if !isQueued {
                    OutgoingBubbleShape(cornerRadius: UserTurnRowView.corner)
                        .fill(Palette.workspaceMessage.opacity(0.08))
                }
                OutgoingBubbleShape(cornerRadius: UserTurnRowView.corner)
                    .strokeBorder(
                        Palette.workspaceMessage.opacity(isQueued ? 1 : 0.45),
                        style: isQueued ? Self.dots : StrokeStyle(lineWidth: Metrics.outline)
                    )
            }
            .scaleEffect(x: -1, y: 1)
        }
    }

    @ViewBuilder
    private var status: some View {
        HStack(spacing: Metrics.gutter) {
            switch message?.state {
            case .queued:
                HStack(spacing: Metrics.spacingSmall) {
                    ProgressView().controlSize(.mini)
                    Text("Queued in their chat").foregroundStyle(Palette.textTertiary)
                }
                Button("Cancel", action: cancel)
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.link)
                    .pointerStyle(.link)
                    .disabled(isCancelling)
                    .help("Takes it back out of their queue before their agent reads it.")
            case .delivered:
                HStack(spacing: Metrics.spacingSmall) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Palette.workspaceMessage)
                        .accessibilityHidden(true)
                    Text(deliveredText).foregroundStyle(Palette.textTertiary)
                }
            case .cancelled:
                Text("Cancelled before it was delivered").foregroundStyle(Palette.textTertiary)
            case nil:
                EmptyView()
            }

            if let id = record.target.workspaceID {
                Button("Open \(record.target.workspace)") { app.revealWorkspace(id) }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.workspaceMessage)
                    .pointerStyle(.link)
            }
        }
        .font(Typo.caption)
    }

    private var deliveredText: String {
        guard let at = message?.deliveredAt else { return "Delivered" }
        return "Delivered \(at.formatted(date: .omitted, time: .shortened))"
    }

    private func cancel() {
        isCancelling = true
        Task {
            await app.cancelWorkspaceMessage(record.messageID)
            isCancelling = false
        }
    }
}
