import SwiftUI
import Core

struct CenterPaneMenu: View {
    var isSplit: Bool
    var split: @MainActor (SplitAxis, PaneKind) -> Void
    var close: @MainActor () -> Void

    var body: some View {
        submenu("Split Right", symbol: PaneSymbol.splitRight, axis: .horizontal)
        submenu("Split Down", symbol: PaneSymbol.splitDown, axis: .vertical)
        if isSplit {
            Divider()
            Button("Close Pane", systemImage: PaneSymbol.closePane, action: close)
                .labelStyle(.titleAndIcon)
        }
    }

    private func submenu(_ title: String, symbol: String, axis: SplitAxis) -> some View {
        Menu(title, systemImage: symbol) {
            PaneKindItems { split(axis, $0) }
        }
        .labelStyle(.titleAndIcon)
    }
}

struct PaneKindItems: View {
    var pick: @MainActor (PaneKind) -> Void

    var body: some View {
        ForEach(PaneKind.allCases) { kind in
            Button(kind.title, systemImage: kind.symbol) { pick(kind) }
        }
        .labelStyle(.titleAndIcon)
    }
}
