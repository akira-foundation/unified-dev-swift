import SwiftUI
import Core

struct QuickPromptMarkPicker: View {
    var selection: String
    var onChoose: @MainActor (QuickPromptMark) -> Void
    var onClose: @MainActor () -> Void

    @State private var kind: QuickPromptMarkKind
    @State private var query = ""
    @State private var highlighted: QuickPromptMark?

    init(
        selection: String,
        onChoose: @escaping @MainActor (QuickPromptMark) -> Void,
        onClose: @escaping @MainActor () -> Void
    ) {
        self.selection = selection
        self.onChoose = onChoose
        self.onClose = onClose

        let current = QuickPromptMark(stored: selection)
        let tab = QuickPromptMarkCatalog.kind(of: current)
        _kind = State(initialValue: tab)
        _highlighted = State(
            initialValue: QuickPromptMarkCatalog.settled(
                QuickPromptMarkCatalog.sections(tab), after: current
            )
        )
    }

    private static let columns = 7
    private static let cell: CGFloat = 36
    private static let inset: CGFloat = Metrics.gutter
    private static let markPoints: CGFloat = 18

    private static let width = CGFloat(columns) * cell + inset * 2
    private static let gridHeight: CGFloat = 5 * cell + Metrics.spacingWide * 2

    private var sections: [QuickPromptMarkSection] {
        QuickPromptMarkCatalog.filtered(kind, query: query)
    }

    var body: some View {
        MenuPanel {
            VStack(alignment: .leading, spacing: Metrics.spacingWide) {
                tabs
                searchRow
            }
            .padding(Self.inset)

            Hairline()

            grid(sections)
        }
        .frame(width: Self.width)
        .onChange(of: kind) { _, tab in
            settle(after: tab)
        }
        .onChange(of: query) { _, _ in
            highlighted = QuickPromptMarkCatalog.settled(self.sections, after: highlighted)
        }
    }

    private var tabs: some View {
        PanelTabs(
            "What to mark this prompt with",
            tabs: QuickPromptMarkKind.allCases,
            selection: $kind,
            title: { $0.title }
        )
    }

    private func settle(after tab: QuickPromptMarkKind) {
        query = ""
        highlighted = QuickPromptMarkCatalog.sections(tab).first?.choices.first?.mark
    }

    private var searchRow: some View {
        HStack(spacing: Metrics.spacing) {
            Image(systemName: "magnifyingglass")
                .imageScale(.small)
                .foregroundStyle(Palette.textTertiary)

            MenuSearchField(
                text: $query,
                placeholder: kind == .icons ? "Search icons" : "Search emoji",
                onKey: handle(key:),
                onHorizontal: handle(horizontal:)
            )
        }
        .padding(.horizontal, Metrics.spacing)
        .frame(height: Metrics.rowHeight)
        .background(
            Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Metrics.cornerSmall)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                .strokeBorder(Palette.border, lineWidth: Metrics.outline)
        }
    }

    @ViewBuilder
    private func grid(_ sections: [QuickPromptMarkSection]) -> some View {
        if sections.isEmpty {
            MenuEmptyRow(text: "Nothing matches \(query)")
                .frame(height: Self.gridHeight, alignment: .top)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Metrics.gutter) {
                        ForEach(sections) { section in
                            band(section)
                        }
                    }
                    .padding(.horizontal, Self.inset)
                    .padding(.vertical, Self.inset)
                }
                .frame(height: Self.gridHeight)
                .onChange(of: highlighted) { _, mark in
                    guard let mark else { return }
                    proxy.scrollTo(mark.stored)
                }
                .onAppear {
                    guard let mark = highlighted else { return }
                    proxy.scrollTo(mark.stored, anchor: .center)
                }
            }
            .id(kind)
        }
    }

    private func band(_ section: QuickPromptMarkSection) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
            if let name = section.name {
                Text(name)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textTertiary)
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(section.rows(across: Self.columns)) { row in
                    HStack(spacing: 0) {
                        ForEach(row.choices) { choice in
                            cell(choice)
                        }
                    }
                }
            }
        }
    }

    private func cell(_ choice: QuickPromptMarkChoice) -> some View {
        let isChosen = choice.mark == QuickPromptMark(stored: selection)
        let isHighlighted = choice.mark == highlighted
        return Button {
            onChoose(choice.mark)
        } label: {
            QuickPromptMarkView(
                stored: choice.mark.stored,
                points: Self.markPoints,
                tint: isChosen ? Palette.selectedEmphasizedText : Palette.textSecondary
            )
            .frame(width: Self.cell, height: Self.cell)
            .background {
                RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                    .fill(fill(chosen: isChosen, highlighted: isHighlighted))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(choice.mark.stored)
        .onHover { if $0 { highlighted = choice.mark } }
        .help(choice.label)
        .accessibilityLabel(choice.label)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    private func fill(chosen: Bool, highlighted: Bool) -> Color {
        if chosen { return Palette.selectedEmphasized }
        return highlighted ? Palette.hover : Color.clear
    }

    private func handle(key: ComposerKey) -> Bool {
        switch key {
        case .up:
            highlighted = QuickPromptMarkCatalog.stepped(
                sections, from: highlighted, by: -Self.columns
            )
            return true
        case .down:
            highlighted = QuickPromptMarkCatalog.stepped(
                sections, from: highlighted, by: Self.columns
            )
            return true
        case .returnKey, .commandReturn:
            guard let highlighted else { return false }
            onChoose(highlighted)
            return true
        case .escape:
            onClose()
            return true
        case .tab:
            kind = kind == .icons ? .emoji : .icons
            return true
        }
    }

    private func handle(horizontal step: Int) -> Bool {
        guard query.isEmpty else { return false }
        highlighted = QuickPromptMarkCatalog.stepped(sections, from: highlighted, by: step)
        return true
    }
}
