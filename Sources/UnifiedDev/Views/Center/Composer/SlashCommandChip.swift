import SwiftUI
import AppKit
import Core

struct SlashCommandChip: View {
    var name: String
    var command: SlashCommand?
    var onRemove: @MainActor () -> Void
    var onOpen: @MainActor (String) -> Void = { path in
        Reveal.inEditor(path, repo: nil)
    }
    var onHover: @MainActor (Bool) -> Void

    @State private var isHovered = false
    @State private var hoverTask: Task<Void, Never>?

    @Environment(\.openInRepoID) private var repoID
    @Environment(\.fontScale) private var fontScale
    @Environment(\.chatFont) private var chatFont

    private static var hoverDelay: Duration { Motion.hoverCardDelay }
    static let maxNameWidth: CGFloat = 340

    var body: some View {
        HStack(spacing: ComposerInlineChipLayout.gap) {
            leading

            Text("/\(name)")
                .font(Font(labelFont))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: Self.maxNameWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            trailing
        }
        .padding(.horizontal, ComposerInlineChipLayout.horizontalPadding)
        .frame(height: chipHeight)
        .fixedSize(horizontal: true, vertical: false)
        .background {
            RoundedRectangle(cornerRadius: ComposerInlineChipLayout.cornerRadius)
                .fill(isHovered ? Palette.hover : Palette.surfaceRaised)
        }
        .overlay {
            RoundedRectangle(cornerRadius: ComposerInlineChipLayout.cornerRadius)
                .strokeBorder(Palette.border, lineWidth: Metrics.outline)
        }
        .contentShape(RoundedRectangle(cornerRadius: ComposerInlineChipLayout.cornerRadius))
        .background {
            if let path { HoverQuickLook(url: URL(fileURLWithPath: path)) }
        }
        .onHover(perform: hover(_:))
        .help(helpText)
        .contextMenu { menu }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Command /\(name)")
        .accessibilityValue(command?.detail ?? "")
        .accessibilityAddTraits(.isStaticText)
        .accessibilityAction(named: "Remove", onRemove)
        .accessibilityActions {
            if path != nil {
                Button("Open", action: open)
                Button("Reveal in Finder") { Reveal.inFinder(path ?? "") }
            }
        }
        .onDisappear { hoverTask?.cancel() }
    }

    @ViewBuilder
    private var leading: some View {
        if isHovered {
            ChipRemoveButton(diameter: iconSize, label: "Remove /\(name)", action: onRemove)
        } else {
            Image(systemName: glyph)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .foregroundStyle(Palette.textSecondary)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if path != nil {
            Button(action: open) {
                Image(systemName: "arrow.up.forward.square")
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .foregroundStyle(Palette.textSecondary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(openTitle)
            .accessibilityLabel(openTitle)
        }
    }

    @ViewBuilder
    private var menu: some View {
        if let path {
            Button("Quick Look") { HoverQuickLookController.shared.show(URL(fileURLWithPath: path)) }
            OpenInItems(target: .file(path), noun: "Skill")
            Divider()
            Button("Reveal in Finder") { Reveal.inFinder(path) }
        }
        Divider()
        Button("Remove /\(name)", action: onRemove)
    }

    private var path: String? { command?.path }

    private var lineFont: NSFont {
        ComposerTextEditor.font(scale: fontScale, face: chatFont)
    }

    private var labelFont: NSFont {
        ComposerInlineChipLayout.labelFont(for: lineFont)
    }

    private var iconSize: CGFloat {
        ComposerInlineChipLayout.iconSize(for: lineFont)
    }

    private var chipHeight: CGFloat {
        ComposerInlineChipLayout.height(for: lineFont)
    }

    private var glyph: String {
        guard let command else { return "questionmark.circle" }
        return switch command.kind {
        case .skill: "sparkles"
        case .command: command.path == nil ? "terminal" : "text.page"
        }
    }

    private var openTitle: String {
        "Open /\(name) in Unified Dev"
    }

    private var helpText: String {
        let detail = command?.detail ?? ""
        return detail.isEmpty ? "/\(name)" : "/\(name)  \(detail)"
    }

    private func open() {
        guard let path else { return }
        onOpen(path)
    }

    private func hover(_ hovering: Bool) {
        isHovered = hovering
        hoverTask?.cancel()

        guard hovering else {
            onHover(false)
            return
        }
        hoverTask = Task {
            try? await Task.sleep(for: Self.hoverDelay)
            guard !Task.isCancelled else { return }
            onHover(true)
        }
    }
}
