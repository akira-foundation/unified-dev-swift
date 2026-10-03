import SwiftUI
import Core

struct SidebarStatusBar: View {
    @Environment(AppModel.self) private var app

    @Binding var filter: SidebarFilter
    @AppStorage(ProjectVisibility.showsHiddenKey) private var showsHiddenProjects = false
    @AppStorage(SidebarGrouping.storageKey) private var storedGrouping = SidebarGrouping.standard.rawValue
    var note: String?
    var onNewWorkspace: () -> Void

    @State private var isShowingLegend = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Metrics.spacingSmall) {
                Menu {
                    SidebarFilterMenuItems(
                        filter: $filter,
                        showsHiddenProjects: $showsHiddenProjects,
                        hiddenCount: ProjectVisibility.hiddenCount(app.repos),
                        grouping: groupingChoice
                    )
                } label: {
                    Label(
                        "Filter the sidebar",
                        systemImage: filter == .all ? "line.3.horizontal.decrease" : filter.icon
                    )
                }
                .labelStyle(.iconOnly)
                .menuStyle(.button)
                .buttonStyle(.plain)
                .frame(width: Metrics.rowHeight, height: Metrics.rowHeight)
                .contentShape(Circle())
                .menuIndicator(.hidden)
                .fixedSize()
                .tint(isDefaultView ? Palette.textSecondary : Palette.accent)
                .help("Filter the sidebar")
                .accessibilityValue(filterValue)

                Button("New workspace", systemImage: "square.and.pencil", action: onNewWorkspace)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .frame(width: Metrics.rowHeight, height: Metrics.rowHeight)
                    .contentShape(Circle())
                    .foregroundStyle(app.repos.isEmpty ? Palette.textDisabled : Palette.textSecondary)
                    .disabled(app.repos.isEmpty)
                    .help("New workspace (\(MenuBarCatalogue[.newWorkspace].keyText))")

                status

                Spacer(minLength: Metrics.spacingSmall)

                Button("What the sidebar glyphs mean", systemImage: "questionmark.circle") {
                    isShowingLegend.toggle()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .frame(width: Metrics.rowHeight, height: Metrics.rowHeight)
                .contentShape(Circle())
                .help("What the sidebar glyphs mean")
                .popover(isPresented: $isShowingLegend, arrowEdge: .top) {
                    SidebarLegend()
                }
            }
            .padding(.horizontal, Metrics.spacingSmall)
            .frame(height: Metrics.rowHeight)
            .glassEffect(.regular, in: Capsule())
            .padding(.horizontal, Metrics.spacingSmall)
            .padding(.top, Metrics.spacingSmall)
            .padding(.bottom, Metrics.spacing)
        }
    }

    private var groupingChoice: Binding<SidebarGrouping> {
        let stored = $storedGrouping
        return Binding(
            get: { SidebarGrouping.resolve(stored.wrappedValue) },
            set: { stored.wrappedValue = $0.rawValue }
        )
    }

    private var isDefaultView: Bool {
        filter == .all && !showsHiddenProjects
            && SidebarGrouping.resolve(storedGrouping) == SidebarGrouping.standard
    }

    private var filterValue: String {
        let shown = showsHiddenProjects ? "\(filter.rawValue), hidden projects showing" : filter.rawValue
        return SidebarGrouping.resolve(storedGrouping) == .status ? shown + ", grouped by status" : shown
    }

    @ViewBuilder
    private var status: some View {
        if let note {
            Label(note, systemImage: "arrow.uturn.backward")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .padding(.leading, Metrics.spacing)
                .lineLimit(1)
                .accessibilityLabel(note)
        }
    }
}
