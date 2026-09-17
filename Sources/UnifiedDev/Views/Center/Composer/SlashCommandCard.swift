import SwiftUI
import Core

struct SlashCommandCardOverlay: View {
    var name: String?
    var command: SlashCommand?
    var availableWidth: CGFloat
    var availableHeight: CGFloat

    var body: some View {
        if let name {
            SlashCommandCard(
                name: name,
                command: command,
                availableWidth: availableWidth,
                availableHeight: availableHeight
            )
        }
    }
}

struct SlashCommandCard: View {
    var name: String
    var command: SlashCommand?
    var availableWidth: CGFloat
    var availableHeight: CGFloat

    private static var maxWidth: CGFloat { HoverCardWidth.ceiling }
    private static let lines = TextHead.lines
    private static let chrome: CGFloat = 150
    private static let lineHeight: CGFloat = 15
    private static let minimumLines = 3

    @State private var documentation: SlashCommandIndex.Documentation?
    @State private var isLoaded = false

    var body: some View {
        MenuPanel {
            VStack(alignment: .leading, spacing: Metrics.spacing) {
                Text("/\(name)")
                    .font(Typo.code)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let detail = command?.detail, !detail.isEmpty {
                    Text(detail)
                        .font(Typo.label)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let documentation, let shown = fitted(documentation) {
                    Hairline()
                    SourceLines(lines: shown.lines, truncated: shown.truncated)
                        .accessibilityHidden(true)
                } else if isLoaded, command?.path == nil {
                    Hairline()
                    Text(builtInNote)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: width, alignment: .leading)
            .padding(Metrics.inset)

            if let path = command?.path {
                Hairline()

                Text(shortened(path))
                    .font(Typo.codeSmall)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Metrics.inset)
                    .padding(.vertical, Metrics.spacing)
            }
        }
        .frame(maxWidth: width + Metrics.inset * 2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: command?.path) { await load() }
    }

    private func fitted(_ documentation: SlashCommandIndex.Documentation) -> SlashCommandIndex.Documentation? {
        let budget = Int(((availableHeight - Self.chrome) / Self.lineHeight).rounded(.down))
        let allowed = max(Self.minimumLines, budget)
        guard documentation.lines.count > allowed else { return documentation }
        return SlashCommandIndex.Documentation(
            lines: Array(documentation.lines.prefix(allowed)),
            truncated: true
        )
    }

    private var builtInNote: String {
        command == nil
            ? "Unified Dev does not know this command. It will be sent as it is written."
            : "Built into the Claude Code CLI, so there is no file to open."
    }

    private var width: CGFloat {
        max(min(availableWidth - Metrics.gutter * 2, Self.maxWidth), 160)
    }

    private func shortened(_ path: String) -> String {
        let home = NSHomeDirectory()
        guard path.hasPrefix(home + "/") else { return path }
        return "~" + path.dropFirst(home.count)
    }

    private func load() async {
        documentation = nil
        isLoaded = false
        guard let path = command?.path else {
            isLoaded = true
            return
        }
        let limit = Self.lines
        let columns = TextHead.columns
        let found = await Task.detached(priority: .userInitiated) {
            SlashCommandIndex.documentation(of: path, lines: limit, columns: columns)
        }.value
        guard !Task.isCancelled else { return }
        documentation = found
        isLoaded = true
    }
}
