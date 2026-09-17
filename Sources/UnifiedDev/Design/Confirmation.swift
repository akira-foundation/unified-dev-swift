import SwiftUI
import AppKit

struct ConfirmationSheet: View {
    let confirmation: Confirmation
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @FocusState private var focus: Field?

    private enum Field: Hashable { case cancel, confirm }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(confirmation.title)
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Layout.textInset)
                .padding(.top, Layout.top)

            Text(confirmation.message)
                .font(Typo.body)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Layout.textInset)
                .padding(.top, Layout.titleToMessage)

            buttons
        }
        .frame(width: width, alignment: .leading)
        .background(.regularMaterial)
        .background(AlertRole())
        .defaultFocus($focus, .cancel)
    }

    @ViewBuilder
    private var buttons: some View {
        switch confirmation.layout {
        case .standard:
            VStack(spacing: Layout.betweenButtons) {
                confirmButton
                cancelButton
            }
            .padding(.horizontal, Layout.buttonInset)
            .padding(.top, Layout.messageToButtons)
            .padding(.bottom, Layout.bottom)
        case .compact:
            HStack(spacing: Layout.compactButtonSpacing) {
                Spacer(minLength: 0)
                compactCancelButton
                compactConfirmButton
            }
            .padding(.horizontal, Layout.textInset)
            .padding(.top, Layout.compactMessageToButtons)
            .padding(.bottom, Layout.compactBottom)
        }
    }

    private var confirmButton: some View {
        Button { onConfirm() } label: {
            Text(confirmation.confirmLabel).frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .foregroundStyle(confirmation.tone.color)
        .background(Capsule().fill(confirmation.tone.color.opacity(Layout.plateTint)))
        .focused($focus, equals: .confirm)
    }

    private var cancelButton: some View {
        Button { onCancel() } label: {
            Text(confirmation.cancelLabel).frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .focused($focus, equals: .cancel)
        .keyboardShortcut(.cancelAction)
    }

    private var compactConfirmButton: some View {
        Button { onConfirm() } label: {
            Text(confirmation.confirmLabel)
                .frame(minWidth: Layout.compactConfirmWidth)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .foregroundStyle(confirmation.tone.color)
        .background(
            RoundedRectangle(cornerRadius: Layout.compactButtonRadius)
                .fill(confirmation.tone.color.opacity(Layout.plateTint))
        )
        .focused($focus, equals: .confirm)
    }

    private var compactCancelButton: some View {
        Button { onCancel() } label: {
            Text(confirmation.cancelLabel)
                .frame(minWidth: Layout.compactCancelWidth)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .focused($focus, equals: .cancel)
        .keyboardShortcut(.cancelAction)
    }

    private enum Layout {
        static let width: CGFloat = 260
        static let compactWidth: CGFloat = 320
        static let textInset: CGFloat = 21
        static let buttonInset: CGFloat = 15
        static let top: CGFloat = 19
        static let titleToMessage: CGFloat = 8
        static let messageToButtons: CGFloat = 14
        static let betweenButtons: CGFloat = 4
        static let bottom: CGFloat = 15
        static let compactMessageToButtons: CGFloat = 18
        static let compactButtonSpacing: CGFloat = 8
        static let compactBottom: CGFloat = 18
        static let compactCancelWidth: CGFloat = 68
        static let compactConfirmWidth: CGFloat = 104
        static let compactButtonRadius: CGFloat = 7
        static let plateTint: Double = 0.13
    }

    private var width: CGFloat {
        confirmation.layout == .compact ? Layout.compactWidth : Layout.width
    }
}

private struct AlertRole: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { Probe() }

    func updateNSView(_ view: NSView, context: Context) {}

    final class Probe: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.setAccessibilityLabel("alert")
        }
    }
}

struct Confirmation: Equatable, Sendable {
    var title: String
    var message: String
    var confirmLabel: String
    var cancelLabel: String
    var tone: ConfirmationTone = .destructive
    var layout: ConfirmationLayout = .standard
}

enum ConfirmationLayout: Equatable, Sendable {
    case standard
    case compact
}

enum ConfirmationTone: Sendable {
    case destructive
    case completing

    var color: Color {
        switch self {
        case .destructive: Palette.negative
        case .completing: Palette.positive
        }
    }
}

extension View {
    func confirmation<Item: Equatable>(
        _ item: Binding<Item?>,
        _ question: @escaping (Item) -> Confirmation,
        onConfirm: @escaping (Item) -> Void,
        onCancel: @escaping () -> Void = {}
    ) -> some View {
        sheet(isPresented: item.isPresent()) {
            if let value = item.wrappedValue {
                ConfirmationSheet(
                    confirmation: question(value),
                    onConfirm: {
                        item.wrappedValue = nil
                        onConfirm(value)
                    },
                    onCancel: {
                        item.wrappedValue = nil
                        onCancel()
                    }
                )
            }
        }
    }
}
