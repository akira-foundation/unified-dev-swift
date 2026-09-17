import SwiftUI
import Core

struct PanelTabsGallery: View {
    var app: AppModel

    private static let panelWidth: CGFloat = 460

    private static let widths: [CGFloat] = [panelWidth - Metrics.gutter * 2, 320, 220, 150]

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.pane) {
            HStack(alignment: .top, spacing: Metrics.pane) {
                captioned("The panel, on the tab that cuts a branch") {
                    panel(tab: .newBranch)
                }
                captioned("The panel, on the tab that carries one on") {
                    panel(tab: .existingBranch)
                }
            }

            captioned("The strip alone, at four widths") {
                VStack(alignment: .leading, spacing: Metrics.spacingWide) {
                    ForEach(Self.widths, id: \.self) { width in
                        strip(width: width)
                    }
                }
            }

            HStack(alignment: .top, spacing: Metrics.pane) {
                captioned("Resting, nothing under the pointer") {
                    strip(width: 300)
                }
                captioned("The pointer on the cell that is not chosen") {
                    strip(width: 300, hovering: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(Metrics.pane)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.surface)
        .environment(app)
    }

    private func panel(tab: WorkspaceSourceTab) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelTabsHarness(tab: tab)
                .padding(.horizontal, Metrics.gutter)
                .padding(.vertical, Metrics.spacingWide)

            Text(tab.explanation)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, Metrics.spacingWide)

            Hairline()

            HStack(spacing: Metrics.spacing) {
                Image(systemName: "magnifyingglass")
                    .imageScale(.small)
                    .foregroundStyle(Palette.textTertiary)
                Text(tab.searchPlaceholder)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textPlaceholder)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.vertical, Metrics.spacingSmall)
            .frame(height: Metrics.rowHeight)

            Hairline()
        }
        .frame(width: Self.panelWidth)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.corner + 2))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.corner + 2)
                .strokeBorder(Palette.border, lineWidth: Metrics.hairline)
        }
    }

    private func strip(width: CGFloat, hovering: Bool = false) -> some View {
        PanelTabsHarness(tab: .newBranch, hovering: hovering ? .existingBranch : nil)
            .frame(width: width)
    }

    private func captioned(_ caption: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacingWide) {
            Text(caption)
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
            content()
        }
    }
}

private struct PanelTabsHarness: View {
    var tab: WorkspaceSourceTab
    var hovering: WorkspaceSourceTab?

    @State private var selection: WorkspaceSourceTab = .newBranch

    var body: some View {
        PanelTabs(
            "Start from",
            tabs: WorkspaceSourceTab.allCases,
            selection: $selection,
            title: { $0.title },
            hovering: hovering
        )
        .onAppear { selection = tab }
    }
}

extension Gallery {
    static let panelTabs = Gallery(
        name: "panel-tabs",
        title: "Panel tabs",
        size: CGSize(width: 1040, height: 780),
        needsFocus: false,
        view: { app in AnyView(PanelTabsGallery(app: app)) }
    )
}
