import SwiftUI
import AppKit
import QuickLookUI
import Core

struct ListKeyboardHost: NSViewRepresentable {
    var url: URL?
    var armToken: Int
    var onKey: (ListKey) -> Bool
    var onFocusChange: (ListFocus) -> Void

    func makeNSView(context: Context) -> ListKeyboardHostView {
        ListKeyboardHostView()
    }

    func updateNSView(_ view: ListKeyboardHostView, context: Context) {
        view.onKey = onKey
        view.onFocusChange = onFocusChange
        view.update(url: url, armToken: armToken)
    }
}

final class ListKeyboardHostView: NSView, @MainActor QLPreviewPanelDataSource, @MainActor QLPreviewPanelDelegate {
    var onKey: (ListKey) -> Bool = { _ in false }
    var onFocusChange: (ListFocus) -> Void = { _ in }

    private var url: URL?
    private var armToken = 0
    private var origin: ListFocusOrigin = .unknown

    override var acceptsFirstResponder: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(url: URL?, armToken: Int) {
        let changed = self.url != url
        self.url = url

        if armToken != self.armToken {
            self.armToken = armToken
            window?.makeFirstResponder(self)
        }

        guard changed, isPanelOpen else { return }
        QLPreviewPanel.shared()?.reloadData()
    }

    private func report(focus: Bool) {
        let value = ListFocus(
            hasKeyboard: focus,
            origin: focus ? origin : .unknown,
            fullKeyboardAccess: NSApp.isFullKeyboardAccessEnabled
        )
        Task { @MainActor in onFocusChange(value) }
    }

    private static func origin(of event: NSEvent?) -> ListFocusOrigin {
        guard let event else { return .unknown }
        switch event.type {
        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
             .otherMouseDown, .otherMouseUp, .leftMouseDragged, .rightMouseDragged,
             .otherMouseDragged, .mouseMoved, .mouseEntered, .mouseExited, .cursorUpdate,
             .scrollWheel:
            return .mouse
        case .keyDown, .keyUp, .flagsChanged:
            return .keyboard
        default:
            return .unknown
        }
    }

    override func becomeFirstResponder() -> Bool {
        origin = Self.origin(of: NSApp.currentEvent)
        report(focus: true)
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        origin = .unknown
        report(focus: false)
        return super.resignFirstResponder()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            origin = .unknown
            report(focus: false)
        }
    }

    private func promoteToKeyboard() {
        guard origin == .mouse else { return }
        origin = .keyboard
        report(focus: true)
    }

    override func keyDown(with event: NSEvent) {
        if isSpace(event) {
            promoteToKeyboard()
            toggle()
            return
        }

        if let key = Self.key(for: event), onKey(key) {
            promoteToKeyboard()
            return
        }
        super.keyDown(with: event)
    }

    static func key(for event: NSEvent) -> ListKey? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .function, .numericPad])
        guard modifiers.isEmpty else { return nil }

        guard let scalar = event.charactersIgnoringModifiers?.unicodeScalars.first else {
            return nil
        }

        switch Int(scalar.value) {
        case NSUpArrowFunctionKey: return .up
        case NSDownArrowFunctionKey: return .down
        case NSLeftArrowFunctionKey: return .left
        case NSRightArrowFunctionKey: return .right
        case NSHomeFunctionKey: return .home
        case NSEndFunctionKey: return .end
        case 0x0D, 0x03: return .activate
        default: break
        }

        guard let character = event.characters?.first,
              !event.modifierFlags.contains(.function) else { return nil }
        return .character(character)
    }

    private func isSpace(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting(.capsLock)
        return modifiers.isEmpty && event.charactersIgnoringModifiers == " "
    }

    private var isPanelOpen: Bool {
        QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared()?.isVisible == true
    }

    private func toggle() {
        guard let panel = QLPreviewPanel.shared() else { return }

        if isPanelOpen {
            panel.orderOut(nil)
            return
        }

        guard url != nil else { return }
        window?.makeFirstResponder(self)
        panel.makeKeyAndOrderFront(nil)
    }

    override nonisolated func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        true
    }

    override nonisolated func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            panel.dataSource = self
            panel.delegate = self
        }
    }

    override nonisolated func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            panel.dataSource = nil
            panel.delegate = nil
        }
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        url == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        url as NSURL?
    }

    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        guard event.type == .keyDown else { return false }

        if isSpace(event) {
            panel.orderOut(nil)
            return true
        }

        guard let key = Self.key(for: event), key == .up || key == .down else { return false }
        return onKey(key)
    }
}

extension View {
    func listKeyboard(
        hasKeyboard: Binding<Bool>,
        previewing url: URL? = nil,
        armToken: Int,
        onKey: @escaping (ListKey) -> Bool
    ) -> some View {
        modifier(
            ListKeyboardModifier(
                hasKeyboard: hasKeyboard,
                url: url,
                armToken: armToken,
                onKey: onKey
            )
        )
    }
}

private struct ListKeyboardModifier: ViewModifier {
    @Binding var hasKeyboard: Bool
    var url: URL?
    var armToken: Int
    var onKey: (ListKey) -> Bool

    @State private var focus = ListFocus()

    func body(content: Content) -> some View {
        content
            .background(
                ListKeyboardHost(
                    url: url,
                    armToken: armToken,
                    onKey: onKey,
                    onFocusChange: { report($0) }
                )
            )
            .modifier(ListFocusRing(isVisible: focus.showsRing))
    }

    private func report(_ next: ListFocus) {
        if focus != next { focus = next }
        if hasKeyboard != next.hasKeyboard { hasKeyboard = next.hasKeyboard }
    }
}

private struct ListFocusRing: ViewModifier {
    var isVisible: Bool

    @Environment(\.controlActiveState) private var activeState

    private static let width: CGFloat = 2

    func body(content: Content) -> some View {
        content
            .overlay {
                if isVisible, activeState != .inactive {
                    RoundedRectangle(cornerRadius: Metrics.corner)
                        .strokeBorder(Palette.focusRing, lineWidth: Self.width)
                        .padding(Self.width / 2)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
    }
}
