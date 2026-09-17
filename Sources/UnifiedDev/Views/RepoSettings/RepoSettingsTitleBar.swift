import AppKit
import SwiftUI
import Core

struct RepoSettingsTitleBar: ViewModifier {
    let repo: Repo

    @State private var window: NSWindow?

    func body(content: Content) -> some View {
        content
            .background(WindowAccessor(window: $window))
            .onChange(of: window, initial: true) { _, _ in apply() }
            .onChange(of: repo.path) { _, _ in apply() }
    }

    private func apply() {
        guard let window else { return }
        window.titleVisibility = .visible
        window.representedURL = URL(filePath: repo.path)
        window.tabbingMode = .disallowed
        if let group = window.tabGroup, group.windows.count > 1 {
            group.removeWindow(window)
        }
    }
}

extension View {
    func showsProjectInTitleBar(_ repo: Repo) -> some View {
        modifier(RepoSettingsTitleBar(repo: repo))
    }
}
