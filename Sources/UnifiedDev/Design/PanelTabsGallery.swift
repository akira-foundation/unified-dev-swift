import SwiftUI
import Core

struct PanelTabsGallery: View {
    var app: AppModel

    private static let widths: [CGFloat] = [420, 320, 220, 150]

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.pane) {
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
        size: CGSize(width: 520, height: 420),
        needsFocus: false,
        view: { app in AnyView(PanelTabsGallery(app: app)) }
    )
}
