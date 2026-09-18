import AppKit
import SwiftUI
import Core

struct WindowTitle: ViewModifier {
    let app: AppModel

    @State private var window: NSWindow?

    private var title: String {
        if let workspace = app.selectedWorkspace { return workspace.name }
        if case .ask = app.selection { return AskConversation.title }
        return WindowTitleMark.defaultTitle
    }

    func body(content: Content) -> some View {
        content
            .background(WindowAccessor(window: $window))
            .onChange(of: title, initial: true) { _, value in apply(value) }
            .onChange(of: window, initial: true) { _, _ in apply(title) }
    }

    private func apply(_ value: String) {
        guard let window else { return }
        window.title = WindowTitleMark.decorate(value)
        window.representedURL = nil
    }
}

extension View {
    func showsWorkspaceInTitleBar(_ app: AppModel) -> some View {
        modifier(WindowTitle(app: app))
    }
}
