import SwiftUI
import Core

struct SubagentConversationView: View {
    var rows: [TranscriptRow]
    var prompt: String
    var home: TranscriptHome
    var droppedRows: Int
    var isRunning: Bool

    @State private var expanded: Set<Int64> = []
    @State private var unfolded: Set<Int> = []
    @State private var isPromptExpanded = false

    var body: some View {
        if !prompt.isEmpty {
            promptBubble
                .subagentReadingColumn()
        }

        if droppedRows > 0 {
            DetailCaption(text: "\(Counted.of(droppedRows, "earlier step")) not shown")
                .padding(.horizontal, TranscriptLayout.inset)
                .padding(.bottom, TranscriptLayout.block)
                .subagentReadingColumn()
        }

        ForEach(entries, id: \.id) { entry in
            content(for: entry)
                .subagentReadingColumn()
        }

        if isRunning {
            StreamingStatusView(glyph: nil, text: "Working")
                .padding(.bottom, TranscriptLayout.block)
                .subagentReadingColumn()
        }
    }

    @ViewBuilder
    private var promptBubble: some View {
        let preview = SubagentPane.briefPreview(prompt)
        VStack(alignment: .trailing, spacing: 0) {
            UserTurnRowView(text: isPromptExpanded ? prompt : (preview ?? prompt), home: home)

            if preview != nil {
                Button(TextFold.title(isExpanded: isPromptExpanded)) {
                    isPromptExpanded.toggle()
                }
                .linkButton()
                .font(Typo.caption)
                .accessibilityLabel(isPromptExpanded ? "Show less of the prompt" : "Show all of the prompt")
                .padding(.horizontal, TranscriptLayout.inset)
                .padding(.bottom, TranscriptLayout.inset)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
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

extension View {
    func subagentReadingColumn() -> some View {
        frame(maxWidth: TranscriptLayout.conversationMeasure, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
