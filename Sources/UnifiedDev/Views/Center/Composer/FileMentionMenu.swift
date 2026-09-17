import SwiftUI
import Core

struct FileMentionMenu: View {
    var matches: [FileMatch]
    var query: String
    var selectedIndex: Int
    var maxHeight: CGFloat = MenuLayout.maxHeight
    var onPick: @MainActor (FileMatch) -> Void
    var onHighlight: @MainActor (Int) -> Void = { _ in }

    var body: some View {
        MenuPanel {
            if matches.isEmpty {
                MenuEmptyRow(
                    text: query.isEmpty ? "No files in this workspace" : "No file matches \(query)"
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(matches.enumerated()), id: \.element.id) { index, match in
                                FileMentionRow(
                                    match: match,
                                    isSelected: index == selectedIndex,
                                    onPick: { onPick(match) },
                                    onHover: { onHighlight(index) }
                                )
                                .id(match.id)
                            }
                        }
                        .padding(Metrics.spacingSmall)
                    }
                    .frame(maxHeight: maxHeight)
                    .onChange(of: selectedIndex) { _, index in
                        guard matches.indices.contains(index) else { return }
                        proxy.scrollTo(matches[index].id)
                    }
                }
            }
        }
    }
}
