import SwiftUI

struct WindowPaneToggle: View {
    enum Edge {
        case leading
        case trailing

        var name: String {
            switch self {
            case .leading: "Sidebar"
            case .trailing: "Inspector"
            }
        }

        var symbol: String {
            switch self {
            case .leading: "sidebar.leading"
            case .trailing: "sidebar.trailing"
            }
        }
    }

    var edge: Edge
    var isVisible: Bool
    var action: @MainActor @Sendable () -> Void
    var body: some View {
        Button(action: action) {
            Label(edge.name, systemImage: edge.symbol)
                .labelStyle(.iconOnly)
        }
        .accessibilityLabel(edge.name)
        .accessibilityValue(isVisible ? "Shown" : "Hidden")
        .help(help)
    }

    private var help: String {
        switch (edge, isVisible) {
        case (.leading, true): "Hide the sidebar"
        case (.leading, false): "Show the sidebar"
        case (.trailing, true): "Hide the changed files"
        case (.trailing, false): "Show the changed files"
        }
    }
}

struct InspectorToggle: View {
    @Binding var isVisible: Bool

    var body: some View {
        WindowPaneToggle(edge: .trailing, isVisible: isVisible) {
            isVisible.toggle()
        }
    }
}
