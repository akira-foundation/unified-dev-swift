import SwiftUI
import Core

struct TodoListView: View {
    var todos: [JSONValue]

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
            ForEach(Array(todos.enumerated()), id: \.offset) { _, todo in
                let status = todo["status"]?.stringValue ?? "pending"

                HStack(alignment: .firstTextBaseline, spacing: TranscriptLayout.glyphGap) {
                    Image(systemName: Self.glyph(status))
                        .font(Typo.label)
                        .imageScale(.small)
                        .foregroundStyle(Self.tint(status))
                        .accessibilityHidden(true)

                    Text(Self.text(of: todo, status: status))
                        .font(Typo.label)
                        .foregroundStyle(status == "completed" ? Palette.textTertiary : Palette.textPrimary)
                        .strikethrough(status == "completed", color: Palette.textTertiary)
                }
            }
        }
    }

    private static func text(of todo: JSONValue, status: String) -> String {
        if status == "in_progress" {
            return todo["activeForm"]?.stringValue ?? todo["content"]?.stringValue ?? ""
        }
        return todo["content"]?.stringValue ?? ""
    }

    private static func glyph(_ status: String) -> String {
        switch status {
        case "completed": "checkmark.square.fill"
        case "in_progress": "square.dashed.inset.filled"
        default: "square"
        }
    }

    private static func tint(_ status: String) -> Color {
        switch status {
        case "completed": Palette.positive
        case "in_progress": Palette.running
        default: Palette.textTertiary
        }
    }
}
