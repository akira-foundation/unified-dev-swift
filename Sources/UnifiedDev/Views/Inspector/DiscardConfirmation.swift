import SwiftUI

struct DiscardConfirmation: ViewModifier {
    var isPresented: Binding<Bool>
    var title: String
    var message: () -> String
    var onConfirm: () -> Void

    func body(content: Content) -> some View {
        content.popover(isPresented: isPresented, arrowEdge: .bottom) {
            ConfirmationPopover(
                title: title,
                confirmLabel: "Discard",
                tint: Palette.negative,
                onConfirm: {
                    isPresented.wrappedValue = false
                    onConfirm()
                },
                onCancel: { isPresented.wrappedValue = false }
            ) {
                Text(message())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

extension View {
    func discardConfirmation(
        isPresented: Binding<Bool>,
        title: String,
        message: @escaping () -> String,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(DiscardConfirmation(
            isPresented: isPresented, title: title, message: message, onConfirm: onConfirm
        ))
    }
}
