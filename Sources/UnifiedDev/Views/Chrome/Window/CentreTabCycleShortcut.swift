import AppKit
import Core

@MainActor
enum CentreTabCycleShortcut {
    private static var monitor: Any?
    private static weak var model: AppModel?

    static func apply() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard let offset = TabCycleStroke.offset(
                keyCode: event.keyCode,
                hasOption: modifiers.contains(.option),
                hasShift: modifiers.contains(.shift),
                hasCommand: modifiers.contains(.command),
                hasControl: modifiers.contains(.control)
            ) else { return event }
            return MainActor.assumeIsolated { cycled(by: offset, in: event.window) } ? nil : event
        }
    }

    static func attach(_ app: AppModel) {
        model = app
    }

    static func cycle(by offset: Int, in app: AppModel) -> Bool {
        if app.selection == .ask {
            guard let next = TabCycle.next(
                from: app.ask.selectedID, in: app.ask.sessions.map(\.id), offset: offset
            ) else { return false }
            Task { await app.ask.select(next) }
            return true
        }
        guard let workspace = app.selectedModel else { return false }
        return WorkspaceTabsStore.shared.selectNextTab(offset: offset, in: workspace)
    }

    private static func cycled(by offset: Int, in window: NSWindow?) -> Bool {
        guard let model, let window, cycles(in: window) else { return false }
        return cycle(by: offset, in: model)
    }

    private static func cycles(in window: NSWindow) -> Bool {
        let target = WindowRoles.target(window)
        return CentreTabCycleTarget.cycles(
            CentreTabCycleTarget.Press(
                role: target.role,
                identifier: window.identifier?.rawValue,
                isSheet: target.isSheet,
                isPanel: window is NSPanel,
                isEditingText: (window.firstResponder as? NSText)?.isEditable == true,
                isEditingThePrompt: window.firstResponder is ComposerTextView
            ),
            mainSceneID: UnifiedDevApp.mainWindowID
        )
    }
}
