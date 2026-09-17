import SwiftUI
import AppKit
import Core

struct ScriptEditor: View {
    @Binding var text: String
    var language: Language = .shell
    var isEditable = true
    var placeholder = ""
    var minimumHeight: CGFloat = 92
    var maximumHeight: CGFloat = 340

    @Environment(\.colorScheme) private var colorScheme

    @State private var draggedHeight: CGFloat?
    @State private var dragOrigin: CGFloat?

    private static let gripHeight: CGFloat = 11

    var body: some View {
        SourceEditor(
            text: $text,
            language: language,
            colorScheme: colorScheme,
            isEditable: isEditable,
            ground: Palette.surfaceSunken,
            placeholder: placeholder
        )
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerSmall))
        .overlay(alignment: .bottom) { grip }
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                .strokeBorder(Palette.border, lineWidth: Metrics.outline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var height: CGFloat {
        draggedHeight ?? min(max(naturalHeight, minimumHeight), maximumHeight)
    }

    private var naturalHeight: CGFloat {
        let lines = max(1, text.components(separatedBy: "\n").count)
        return CGFloat(lines) * CodeMetrics.rowHeight + Self.verticalPadding
    }

    private static let verticalPadding: CGFloat = 12 + gripHeight

    private var grip: some View {
        ZStack {
            Rectangle()
                .fill(Palette.border)
                .frame(width: 22, height: Metrics.hairline)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.gripHeight)
        .contentShape(Rectangle())
        .resizeCursor(.resizeUpDown)
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    let origin = dragOrigin ?? height
                    dragOrigin = origin
                    draggedHeight = min(
                        max(origin + value.translation.height, minimumHeight), maximumHeight
                    )
                }
                .onEnded { _ in dragOrigin = nil }
        )
        .accessibilityLabel("Resize the script editor")
    }
}
