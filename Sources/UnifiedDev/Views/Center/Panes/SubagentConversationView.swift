import SwiftUI
import Core

struct SubagentConversationView: View {
    var rows: [TranscriptRow]
    var home: TranscriptHome
    var droppedRows: Int

    @State private var expanded: Set<Int64> = []

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if droppedRows > 0 {
                DetailCaption(text: "\(Counted.of(droppedRows, "earlier step")) not shown")
                    .padding(.horizontal, TranscriptLayout.inset)
                    .padding(.bottom, TranscriptLayout.block)
            }

            ForEach(rows) { row in
                TranscriptRowView(
                    row: row,
                    home: home,
                    isExpanded: expanded.contains(row.id),
                    projectName: nil,
                    onToggle: { toggle(row.id) }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggle(_ id: Int64) {
        if expanded.contains(id) {
            expanded.remove(id)
        } else {
            expanded.insert(id)
        }
    }
}
