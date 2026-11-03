import SwiftUI
import Core

struct CanvasContextBar: View {
    let count: Int
    let align: (CanvasAlignEdge) -> Void
    let distribute: (CanvasAxis) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(CanvasAlignEdge.allCases, id: \.self) { edge in
                Button { align(edge) } label: { Image(systemName: edge.symbol) }
                    .help(edge.title)
                    .accessibilityLabel(edge.title)
            }
            Divider().frame(height: 18)
            ForEach([CanvasAxis.horizontal, .vertical], id: \.self) { axis in
                Button { distribute(axis) } label: { Image(systemName: axis.symbol) }
                    .disabled(count < 3)
                    .help(axis.title)
                    .accessibilityLabel(axis.title)
            }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: Capsule())
    }
}

private extension CanvasAlignEdge {
    var title: String {
        switch self {
        case .left: "Align Left"
        case .centreX: "Align Centre Horizontally"
        case .right: "Align Right"
        case .top: "Align Top"
        case .middleY: "Align Middle Vertically"
        case .bottom: "Align Bottom"
        }
    }

    var symbol: String {
        switch self {
        case .left: "align.horizontal.left"
        case .centreX: "align.horizontal.center"
        case .right: "align.horizontal.right"
        case .top: "align.vertical.top"
        case .middleY: "align.vertical.center"
        case .bottom: "align.vertical.bottom"
        }
    }
}

private extension CanvasAxis {
    var title: String {
        switch self {
        case .horizontal: "Distribute Horizontally"
        case .vertical: "Distribute Vertically"
        }
    }

    var symbol: String {
        switch self {
        case .horizontal: "distribute.horizontal.center"
        case .vertical: "distribute.vertical.center"
        }
    }
}
