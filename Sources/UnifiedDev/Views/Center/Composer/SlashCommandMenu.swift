import SwiftUI
import Core

struct SlashCommandMenu: View {
    var matches: [SlashCommandMatch]
    var query: String
    var isLoaded: Bool
    var selectedIndex: Int
    var maxHeight: CGFloat = MenuLayout.maxHeight
    var availableWidth: CGFloat = Self.maxWidth + Metrics.gutter * 2
    var onPick: @MainActor (SlashCommand) -> Void
    var onHighlight: @MainActor (Int) -> Void = { _ in }

    var body: some View {
        MenuPanel {
            if matches.isEmpty {
                MenuEmptyRow(text: emptyText)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(matches.enumerated()), id: \.element.id) { index, match in
                                SlashCommandRow(
                                    match: match,
                                    isSelected: index == selectedIndex,
                                    onPick: { onPick(match.command) },
                                    onHover: { onHighlight(index) }
                                )
                                .id(match.id)
                            }
                        }
                        .padding(.horizontal, Metrics.spacingSmall)
                    }
                    .contentMargins(.vertical, Metrics.spacing, for: .scrollContent)
                    .frame(maxHeight: maxHeight)
                    .onChange(of: selectedIndex) { _, index in
                        guard matches.indices.contains(index) else { return }
                        proxy.scrollTo(matches[index].id)
                    }
                }
            }
        }
        .frame(width: panelWidth)
    }

    private static let maxWidth: CGFloat = 440

    private var panelWidth: CGFloat {
        max(160, availableWidth)
    }

    private var emptyText: String {
        guard isLoaded else { return "Looking for commands\u{2026}" }
        guard !query.isEmpty else {
            return "No commands, skills or plugins found for Claude Code"
        }
        return "No command matches /\(query)"
    }
}
