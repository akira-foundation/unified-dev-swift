import SwiftUI
import Core

struct WorkspaceDraftDiscardQuestion: View {
    var onDiscard: @MainActor () -> Void
    var onKeep: @MainActor () -> Void

    var body: some View {
        ConfirmationSheet(
            confirmation: Confirmation(
                title: WorkspaceDraftDiscard.title,
                message: WorkspaceDraftDiscard.message,
                confirmLabel: WorkspaceDraftDiscard.confirmLabel,
                cancelLabel: WorkspaceDraftDiscard.cancelLabel,
                layout: .compact
            ),
            onConfirm: onDiscard,
            onCancel: onKeep
        )
    }
}
