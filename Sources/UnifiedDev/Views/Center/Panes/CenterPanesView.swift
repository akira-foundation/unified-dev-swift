import SwiftUI
import Core

struct CenterPanesView: View {
    @Bindable var model: WorkspaceModel

    private var tabs: WorkspaceTabsStore { .shared }

    private static let dividerThickness: Double = 1

    nonisolated static let space = "unifieddev.centrePanes"

    nonisolated static let soloPane = "solo"

    private struct PaneMove: Equatable {
        var pane: String
        var point: CGPoint
        var landing: PaneLanding?
    }

    @State private var move: PaneMove?

    var body: some View {
        let tab = tabs.selectedTab(in: model)
        let layout = tab.map { tabs.layout(of: $0) } ?? SplitLayout(pane: Self.soloPane)

        return GeometryReader { proxy in
            let geometry = layout.geometry(in: proxy.size, dividerThickness: Self.dividerThickness)

            ZStack(alignment: .topLeading) {
                if proxy.size.width > 1, proxy.size.height > 1 {
                    let isSolo = geometry.panes.count == 1
                    ForEach(geometry.panes, id: isSolo ? \.soloIdentity : \.pane) { item in
                        CenterPaneView(
                            model: model,
                            tab: tab,
                            pane: item.pane,
                            isSplit: layout.paneCount > 1
                        )
                        .frame(width: item.frame.width, height: item.frame.height)
                        .clipped()
                        .position(x: item.frame.midX, y: item.frame.midY)
                    }

                    ForEach(geometry.dividers, id: \.path) { divider in
                        let sides = layout.sides(at: divider.path)
                        CenterPaneDivider(
                            axis: divider.axis,
                            ratio: divider.ratio,
                            span: divider.span,
                            length: divider.axis == .horizontal
                                ? divider.frame.height
                                : divider.frame.width,
                            line: divider.frame,
                            first: sides?.first,
                            second: sides?.second,
                            onResize: { ratio in
                                guard let tab else { return }
                                tabs.setRatio(ratio, at: divider.path, in: tab)
                            },
                            onResizeEnded: {
                                guard let tab else { return }
                                tabs.persistRatio(in: tab)
                            },
                            onMoveChanged: { pane, point in
                                move = PaneMove(
                                    pane: pane,
                                    point: point,
                                    landing: landing(of: pane, at: point, in: geometry, of: layout)
                                )
                            },
                            onMoveEnded: { pane, point in
                                move = nil
                                guard let tab else { return }
                                commit(pane, at: point, in: geometry, of: layout, tab: tab)
                            }
                        )
                        .position(x: divider.frame.midX, y: divider.frame.midY)
                    }

                    if let move {
                        if let landing = move.landing {
                            Rectangle()
                                .fill(Palette.accent.opacity(0.12))
                                .frame(width: landing.frame.width, height: landing.frame.height)
                                .position(x: landing.frame.midX, y: landing.frame.midY)
                                .allowsHitTesting(false)
                        }
                        ghost(of: move, in: tab)
                    }
                }
            }
            .coordinateSpace(.named(Self.space))
        }
    }

    private func landing(
        of pane: String, at point: CGPoint, in geometry: SplitGeometry, of layout: SplitLayout
    ) -> PaneLanding? {
        guard let landing = geometry.landing(at: point) else { return nil }
        var probe = layout
        return apply(pane, to: landing, in: &probe) ? landing : nil
    }

    @discardableResult
    private func apply(_ pane: String, to landing: PaneLanding, in layout: inout SplitLayout) -> Bool {
        guard let placement = landing.region.placement else {
            return layout.exchange(pane, with: landing.pane)
        }
        return layout.move(
            pane, beside: landing.pane, axis: placement.axis, before: placement.before
        )
    }

    private func commit(
        _ pane: String, at point: CGPoint, in geometry: SplitGeometry, of layout: SplitLayout,
        tab: PaneContent
    ) {
        guard let landing = landing(of: pane, at: point, in: geometry, of: layout) else { return }

        if let placement = landing.region.placement {
            tabs.move(
                pane: pane, beside: landing.pane,
                axis: placement.axis, before: placement.before,
                in: tab, of: model
            )
        } else {
            tabs.exchange(pane: pane, with: landing.pane, in: tab, of: model)
        }
    }

    private static let ghostSize = CGSize(width: 96, height: 56)

    @ViewBuilder
    private func ghost(of move: PaneMove, in tab: PaneContent?) -> some View {
        let symbol = tab.map { icon(of: tabs.content(of: move.pane, in: $0)) } ?? PaneKind.chat.symbol

        RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
            .fill(Palette.surface)
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
                    .strokeBorder(Palette.border, lineWidth: Metrics.outline)
            }
            .overlay { Image(systemName: symbol).foregroundStyle(Palette.textSecondary) }
            .frame(width: Self.ghostSize.width, height: Self.ghostSize.height)
            .elevation(.lifted)
            .position(x: move.point.x, y: move.point.y)
            .allowsHitTesting(false)
    }

    private func icon(of content: PaneContent) -> String {
        switch content {
        case .chat:
            return PaneKind.chat.symbol
        case .tool(let id):
            let open = CenterTabStore.shared.tabs(for: model.workspace.id)
            return open.first { $0.id == id }?.icon ?? PaneKind.terminal.symbol
        }
    }
}

extension SplitPaneFrame {
    var soloIdentity: String { CenterPanesView.soloPane }
}
