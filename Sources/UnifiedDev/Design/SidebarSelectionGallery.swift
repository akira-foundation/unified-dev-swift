import SwiftUI
import AppKit
import Core

struct SidebarSelectionGallery: View {
    @State private var selection: Set<String> = ["home", "workspace"]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Sidebar selection")
                .font(Typo.title)
            Text("A top level row and a workspace row, both selected, in a focused source list.")
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)

            List(selection: $selection) {
                Section {
                    row("Home", "house", "home")
                }

                Section("Projects") {
                    row("workspace row", "arrow.triangle.branch", "workspace")
                    row("limits panel", "arrow.triangle.branch", "other")
                }
            }
            .listStyle(.sidebar)
            .background(FirstResponderProbe())
            .frame(height: 300)

            Button("Choose a folder", systemImage: "folder") {}
                .buttonStyle(.borderedProminent)
                .tint(Palette.controlAccent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(_ title: String, _ icon: String, _ tag: String) -> some View {
        SidebarNavRow(title: title, icon: icon)
            .tag(tag)
            .selectedRowInk(isEmphasized: selection.contains(tag))
    }
}

private struct FirstResponderProbe: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window, let root = window.contentView,
                  let table = Self.firstTable(under: root)
            else { return }
            window.makeFirstResponder(table)
        }
    }

    private static func firstTable(under view: NSView) -> NSTableView? {
        if let table = view as? NSTableView { return table }
        for subview in view.subviews {
            if let found = firstTable(under: subview) { return found }
        }
        return nil
    }
}

extension Gallery {
    static let sidebarSelection = Gallery(
        name: "sidebar-selection",
        title: "Sidebar selection",
        size: CGSize(width: 520, height: 520),
        needsFocus: true,
        view: { _ in AnyView(SidebarSelectionGallery()) }
    )
}
