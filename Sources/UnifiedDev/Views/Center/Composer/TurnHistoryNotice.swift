import SwiftUI
import Core

struct TurnHistoryNotice: View {
    var transcript: TranscriptModel
    @Environment(AppModel.self) private var app
    @State private var confirmsRecovery = false

    private static let rewindTitle = "A rewind needs recovery before this workspace can continue."

    private var recoveryModel: (session: SessionID, model: WorkspaceModel)? {
        guard let id = transcript.history.blockingSessionID, let workspace = transcript.workspace,
              let model = app.existingModel(for: workspace.id) else { return nil }
        return (id, model)
    }

    var body: some View {
        if transcript.history.pendingRewind != nil {
            NoticePiece(tone: .warning, announcement: NoticeTone.warning.spoken(Self.rewindTitle)) {
                VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                    Text(Self.rewindTitle)
                        .font(Typo.labelEmphasis)
                        .foregroundStyle(Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let failure = transcript.history.failure {
                        Text(failure)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
            } actions: {
                Button("Resolve Rewind") { confirmsRecovery = true }
                    .buttonStyle(.glass)
                    .disabled(transcript.history.isRewinding)
            }
            .noticeMaterial(.warning)
            .alert("Resolve the interrupted rewind?", isPresented: $confirmsRecovery) {
                Button("Cancel", role: .cancel) {}
                Button("Resolve Rewind") {
                    Task { await transcript.history.recover(transcript: transcript, app: app) }
                }
            } message: {
                Text("Unified Dev checks the agent's history, then completes the rewind or restores the saved files and staging. Later file edits may be replaced. Stop terminal commands first.")
            }
        } else {
            failureNotice
        }
    }

    @ViewBuilder
    private var failureNotice: some View {
        if let failure = transcript.history.failure {
            let recovery = recoveryModel
            NoticePiece(
                tone: .error,
                announcement: NoticeTone.error.spoken(failure),
                onDismiss: recovery == nil ? { transcript.history.failure = nil } : nil
            ) {
                Text(failure)
                    .font(Typo.label)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            } actions: {
                if let recovery {
                    Button("Open Recovery Chat") {
                        WorkspaceTabsStore.shared.reveal(.chat(recovery.session), in: recovery.model)
                    }
                        .buttonStyle(.glass)
                }
            }
            .noticeMaterial(.error)
        }
    }
}

private extension View {
    func noticeMaterial(_ tone: NoticeTone) -> some View {
        noticeGlass(tone)
            .padding(.bottom, Metrics.spacingSmall)
    }
}
