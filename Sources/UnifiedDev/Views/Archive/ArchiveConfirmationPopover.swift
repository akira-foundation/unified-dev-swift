import SwiftUI
import Core

struct ArchiveConfirmationPopover: View {
    let request: ArchiveRequest
    var canConfirm = true
    var tint: Color = Palette.controlAccent
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ConfirmationPopover(
            title: "Archive this workspace?",
            confirmLabel: request.confirmLabel,
            tint: tint,
            canConfirm: canConfirm,
            onConfirm: onConfirm,
            onCancel: onCancel,
            width: 380
        ) {
            ViewThatFits(in: .vertical) {
                Text(request.message).fixedSize(horizontal: false, vertical: true)
                ScrollView {
                    Text(request.message).frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .frame(maxHeight: 440)
        }
    }
}

extension View {
    func archiveConfirmation(
        _ request: Binding<ArchiveRequest?>,
        arrowEdge: Edge = .top,
        canConfirm: Bool = true,
        tint: Color = Palette.controlAccent,
        onConfirm: @escaping (ArchiveRequest) -> Void
    ) -> some View {
        popover(item: request, arrowEdge: arrowEdge) { value in
            ArchiveConfirmationPopover(
                request: value,
                canConfirm: canConfirm,
                tint: tint,
                onConfirm: {
                    request.wrappedValue = nil
                    onConfirm(value)
                },
                onCancel: { request.wrappedValue = nil }
            )
        }
    }
}
