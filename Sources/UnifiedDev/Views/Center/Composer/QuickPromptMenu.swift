import SwiftUI
import Core

struct QuickPromptMenu: View {
    var catalog: QuickPromptCatalog
    var projectPrompts: [ProjectQuickPrompt] = []
    @Binding var draft: QuickPromptFormDraft?
    var onPick: @MainActor (QuickPromptPanelRow) -> Void
    var onClose: @MainActor () -> Void

    @Environment(AppModel.self) private var app

    @State private var query = ""
    @State private var selected: QuickPromptPanelRow?
    @State private var isNewHovered = false
    @State private var contentHeight: CGFloat = 0
    @State private var deleting: QuickPrompt?

    private static let width: CGFloat = 380

    private static let listInset: CGFloat = Metrics.spacingWide
    private static let rowInset: CGFloat = Metrics.spacing
    private static var contentInset: CGFloat { listInset + rowInset }
    private static let listHeight: CGFloat = 260

    private var matches: QuickPromptPanelMatches {
        QuickPromptPanelMatches.ranking(personal: catalog.prompts, project: projectPrompts, query: query)
    }

    var body: some View {
        Group {
            if draft != nil {
                form
            } else {
                list
            }
        }
        .frame(width: Self.width)
        .task { await catalog.load(from: app.store) }
        .confirmation($deleting) {
            QuickPromptDeletion.confirmation(for: $0)
        } onConfirm: { prompt in
            delete(prompt)
            if draft?.editing?.id == prompt.id { draft = nil }
        }
    }

    private var list: some View {
        let matches = self.matches
        return VStack(alignment: .leading, spacing: 0) {
            searchRow
            Hairline()

            if let notice = matches.notice(isLoaded: catalog.isLoaded) {
                empty(notice)
            } else {
                rows(matches)
            }

            Hairline()
            newRow
        }
        .onAppear {
            query = ""
            selected = QuickPromptPanelMatches.ranking(
                personal: catalog.prompts, project: projectPrompts, query: ""
            ).rows.first
        }
        .onChange(of: catalog.prompts) { _, _ in
            selected = matches.settled(after: selected)
        }
        .onChange(of: projectPrompts) { _, _ in
            selected = matches.settled(after: selected)
        }
    }

    private var searchRow: some View {
        HStack(spacing: Metrics.spacing) {
            Image(systemName: "magnifyingglass")
                .imageScale(.small)
                .foregroundStyle(Palette.textTertiary)
                .frame(width: Metrics.repoIcon)

            MenuSearchField(
                text: $query,
                placeholder: "Search quick prompts",
                onKey: handle(key:)
            )
            .frame(height: Metrics.rowHeight)
        }
        .padding(.horizontal, Self.contentInset)
        .padding(.vertical, Metrics.spacingSmall)
        .onChange(of: query) { _, _ in
            selected = matches.settled(after: selected)
        }
    }

    private func rows(_ matches: QuickPromptPanelMatches) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(matches.personal) { prompt in
                        row(.personal(prompt))
                    }

                    if matches.showsProjectHeading {
                        projectHeading(below: !matches.personal.isEmpty)
                        ForEach(matches.project) { prompt in
                            row(.project(prompt))
                        }
                    }
                }
                .padding(.horizontal, Self.listInset)
                .padding(.vertical, Metrics.spacingSmall)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            .frame(height: height(for: matches))
            .onChange(of: selected) { _, row in
                guard let row else { return }
                proxy.scrollTo(row.id)
            }
        }
    }

    private func row(_ row: QuickPromptPanelRow) -> some View {
        QuickPromptRow(
            row: row,
            isSelected: row.id == selected?.id,
            onPick: { pick(row) },
            onHover: { selected = row },
            onEdit: {
                guard case .personal(let prompt) = row else { return }
                draft = QuickPromptFormDraft(editing: prompt)
            },
            onDelete: {
                guard case .personal(let prompt) = row else { return }
                deleting = prompt
            },
            onCopy: {
                guard case .project(let prompt) = row else { return }
                copy(prompt)
            }
        )
        .id(row.id)
    }

    private func projectHeading(below hasSectionAbove: Bool) -> some View {
        Text("Project")
            .font(Typo.captionEmphasis)
            .foregroundStyle(Palette.textSecondary)
            .padding(.horizontal, Self.rowInset)
            .padding(.top, hasSectionAbove ? Metrics.spacing : Metrics.spacingTight)
            .padding(.bottom, Metrics.spacingTight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func empty(_ notice: QuickPromptPanelNotice) -> some View {
        switch notice {
        case .noMatches(let query):
            MenuEmptyRow(text: "Nothing matches \(query)", inset: Self.contentInset)
        case .loading:
            MenuEmptyRow(text: "Looking for quick prompts\u{2026}", inset: Self.contentInset)
        case .nothingYet:
            VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                Text("Nothing here yet.")
                    .font(Typo.label)
                    .foregroundStyle(Palette.textSecondary)
                Text("A quick prompt is a few lines you find yourself typing again.")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Self.contentInset)
            .padding(.vertical, Metrics.gutter)
        }
    }

    private var newRow: some View {
        Button {
            draft = QuickPromptFormDraft(suggestedName: matches.isEmpty ? query : "")
        } label: {
            HStack(spacing: Metrics.gutter) {
                Image(systemName: "plus")
                    .imageScale(.medium)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: Metrics.repoIcon, height: Metrics.repoIcon)

                Text(newRowTitle)
                    .font(Typo.label)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Self.rowInset)
            .frame(height: Metrics.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .rowBackground(isSelected: false, isHovered: isNewHovered, isFocused: true)
        .onHover { isNewHovered = $0 }
        .padding(.horizontal, Self.listInset)
        .padding(.vertical, Metrics.spacingSmall)
    }

    private func height(for matches: QuickPromptPanelMatches) -> CGFloat {
        let measured = contentHeight > 0
            ? contentHeight
            : Self.estimatedHeight(rows: matches.rows.count, heading: matches.showsProjectHeading)
        return min(max(measured, Metrics.rowHeight), Self.listHeight)
    }

    private static func estimatedHeight(rows: Int, heading: Bool) -> CGFloat {
        CGFloat(rows) * (Metrics.rowHeight + Metrics.gutter) + Metrics.spacingWide
            + (heading ? Metrics.rowHeight - Metrics.spacingSmall : 0)
    }

    private var newRowTitle: String {
        guard matches.isEmpty, !query.isEmpty else { return "New quick prompt" }
        return "New quick prompt named \u{201C}\(query)\u{201D}"
    }

    private var form: some View {
        QuickPromptForm(
            draft: Binding(
                get: { draft ?? QuickPromptFormDraft() },
                set: { draft = $0 }
            ),
            onCancel: { draft = nil },
            onSave: { fields in save(draft?.editing, fields) },
            onDelete: {
                guard let editing = draft?.editing else { return }
                deleting = editing
            }
        )
    }

    private func pick(_ row: QuickPromptPanelRow) {
        onClose()
        onPick(row)
    }

    private func copy(_ prompt: ProjectQuickPrompt) {
        let catalog = catalog
        let store = app.store
        Task {
            let written = await catalog.add(prompt.personalFields, in: store)
            if let written { selected = .personal(written) }
        }
    }

    private func save(_ editing: QuickPrompt?, _ fields: QuickPrompt.Fields) {
        let catalog = catalog
        let store = app.store
        draft = nil
        Task {
            if let editing {
                await catalog.save(id: editing.id, fields, in: store)
            } else {
                let written = await catalog.add(fields, in: store)
                if let written { selected = .personal(written) }
            }
        }
    }

    private func delete(_ prompt: QuickPrompt) {
        let catalog = catalog
        let store = app.store
        Task { await catalog.delete(id: prompt.id, in: store) }
    }

    private func handle(key: ComposerKey) -> Bool {
        switch key {
        case .up:
            selected = matches.stepped(from: selected, by: -1)
            return true
        case .down:
            selected = matches.stepped(from: selected, by: 1)
            return true
        case .returnKey, .commandReturn:
            guard let selected else {
                guard !query.isEmpty else { return false }
                draft = QuickPromptFormDraft(suggestedName: query)
                return true
            }
            pick(matches.rows.first { $0.id == selected.id } ?? selected)
            return true
        case .escape:
            onClose()
            return true
        case .tab:
            return false
        }
    }
}
