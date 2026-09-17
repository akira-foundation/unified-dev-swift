import SwiftUI
import Core

struct WorkspaceSourcePicker: View {
    var offering: WorkspaceSourceOffering
    var checkout: WorkspaceCheckout?
    var baseBranch: String
    var unavailable: String?
    var onPick: @MainActor (WorkspaceSource) -> Void

    @State private var isPresented = false
    @State private var query = ""
    @State private var tab: WorkspaceSourceTab = .newBranch
    @State private var selected: WorkspaceSource?

    private static let width: CGFloat = 460
    private static let listHeight: CGFloat = 320

    private var matches: WorkspaceSourceMatches {
        offering.search(query: query)
    }

    private var label: String {
        WorkspaceSource.label(for: checkout, baseBranch: baseBranch)
    }

    private var glyph: String {
        switch checkout {
        case .pullRequest: "arrow.triangle.pull"
        case .branch: "arrow.triangle.branch"
        case .none: "plus.circle"
        }
    }

    var body: some View {
        GlassEffectContainer(spacing: Metrics.spacingSmall) {
            HStack(spacing: Metrics.spacingSmall) {
                sourceButton

                if checkout == nil {
                    Button {
                        present(.existingBranch)
                    } label: {
                        ComposerControlLabel(
                            systemImage: "arrow.triangle.branch",
                            text: "Open existing branch…",
                            tint: Palette.controlAccent
                        )
                    }
                    .buttonStyle(.glass)
                    .fixedSize()
                    .help("Open a workspace on an existing branch or pull request")
                }
            }
        }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            panel
        }
    }

    private var sourceButton: some View {
        Button {
            present(checkout == nil ? .newBranch : .existingBranch)
        } label: {
            ComposerControlLabel(
                systemImage: glyph,
                text: label,
                isActive: isPresented,
                showsMenuIndicator: true
            )
        }
        .buttonStyle(.glass)
        .fixedSize()
        .help("Open a pull request or a branch, or cut a new branch")
        .accessibilityLabel("Start from")
        .accessibilityValue(label)
    }

    private func present(_ openingTab: WorkspaceSourceTab) {
        query = ""
        tab = openingTab
        selected = offering.search(query: "").rows(in: tab).first
        isPresented = true
    }

    private var panel: some View {
        let matches = self.matches
        return VStack(alignment: .leading, spacing: 0) {
            tabs
            explanation
            Hairline()
            searchRow
            Hairline()

            Group {
                if matches.isEmpty(in: tab) {
                    MenuEmptyRow(
                        text: query.isEmpty ? emptyTabText : "Nothing matches \(query)"
                    )
                } else {
                    list(matches)
                }
            }
            .frame(height: Self.listHeight, alignment: .top)

            if let unavailable, tab == .existingBranch {
                Hairline()
                Text(unavailable)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(1)
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.vertical, Metrics.spacingWide)
            }
        }
        .frame(width: Self.width)
        .background { tabShortcuts }
    }

    private var tabs: some View {
        PanelTabs("Start from", tabs: WorkspaceSourceTab.allCases, selection: $tab) { $0.title }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, Metrics.spacingWide)
        .padding(.bottom, Metrics.spacingWide)
        .onChange(of: tab) { _, _ in
            selected = matches.settled(after: selected, in: tab)
        }
    }

    private var explanation: some View {
        Text(tab.explanation)
            .font(Typo.caption)
            .foregroundStyle(Palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, Metrics.spacingWide)
    }

    private var emptyTabText: String {
        switch tab {
        case .newBranch: "No branches to start from yet"
        case .existingBranch: "No branches or pull requests to carry on yet"
        }
    }

    private var searchRow: some View {
        HStack(spacing: Metrics.spacing) {
            Image(systemName: "magnifyingglass")
                .imageScale(.small)
                .foregroundStyle(Palette.textTertiary)

            MenuSearchField(
                text: $query,
                placeholder: tab.searchPlaceholder,
                onKey: handle(key:)
            )
            .frame(height: Metrics.rowHeight)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, Metrics.spacingSmall)
        .onChange(of: query) { _, _ in
            selected = matches.settled(after: selected, in: tab)
        }
    }

    private func list(_ matches: WorkspaceSourceMatches) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(matches.rows(in: tab)) { row in
                        WorkspaceSourceRow(
                            source: row,
                            isSelected: row == selected,
                            onPick: { pick(row) },
                            onHover: { selected = row }
                        )
                        .id(row.id)
                    }
                }
                .padding(Metrics.spacingSmall)
            }
            .onChange(of: selected) { _, row in
                guard let row else { return }
                proxy.scrollTo(row.id)
            }
        }
    }

    private var tabShortcuts: some View {
        ZStack {
            Button("Previous tab") { tab = tab.stepped(by: -1) }
                .keyboardShortcut("[", modifiers: [.command, .shift])
            Button("Next tab") { tab = tab.stepped(by: 1) }
                .keyboardShortcut("]", modifiers: [.command, .shift])
        }
        .opacity(0)
        .accessibilityHidden(true)
    }

    private func handle(key: ComposerKey) -> Bool {
        switch key {
        case .up:
            selected = matches.stepped(from: selected, by: -1, in: tab)
            return true
        case .down:
            selected = matches.stepped(from: selected, by: 1, in: tab)
            return true
        case .returnKey, .commandReturn:
            guard let selected else { return false }
            pick(selected)
            return true
        case .escape:
            isPresented = false
            return true
        case .tab:
            return false
        }
    }

    private func pick(_ source: WorkspaceSource) {
        isPresented = false
        onPick(source)
    }
}
