import SwiftUI
import Core

struct SubagentConversationView: View {
    var rows: [TranscriptRow]
    var home: TranscriptHome
    var droppedRows: Int

    @State private var expanded: Set<Int64> = []
    @State private var unfolded: Set<Int> = []

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if droppedRows > 0 {
                DetailCaption(text: "\(Counted.of(droppedRows, "earlier step")) not shown")
                    .padding(.horizontal, TranscriptLayout.inset)
                    .padding(.bottom, TranscriptLayout.block)
            }

            ForEach(entries, id: \.id) { entry in
                content(for: entry)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var entries: [SubagentConversation.Entry] {
        SubagentConversation.entries(
            facts: rows.map { $0.foldFact(seq: Int($0.id)) },
            unfolded: unfolded,
            revealed: Set(expanded.map { Int($0) })
        )
    }

    @ViewBuilder
    private func content(for entry: SubagentConversation.Entry) -> some View {
        switch entry {
        case let .fold(firstSeq, hiding, showsMore, isFolded):
            TranscriptFoldRowView(
                hiddenCount: hiding,
                showsMore: showsMore,
                isExpanded: !isFolded,
                onToggle: { toggle(&unfolded, firstSeq) }
            )
            .padding(.horizontal, TranscriptLayout.inset)
        case let .row(index, _):
            let row = rows[index]
            TranscriptRowView(
                row: row,
                home: home,
                isExpanded: expanded.contains(row.id),
                projectName: nil,
                onToggle: { toggle(&expanded, row.id) }
            )
        }
    }

    private func toggle<ID: Hashable>(_ set: inout Set<ID>, _ id: ID) {
        if set.contains(id) {
            set.remove(id)
        } else {
            set.insert(id)
        }
    }
}
