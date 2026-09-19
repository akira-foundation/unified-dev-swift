import SwiftUI
import Core

struct TabSurface: Equatable {
    var fill: Color
    var ink: Color
    var inkMuted: Color

    static func pane(_ fill: Color) -> TabSurface {
        TabSurface(fill: fill, ink: Palette.textPrimary, inkMuted: Palette.textSecondary)
    }

    static func themed(fill: Color, ink: Color) -> TabSurface {
        TabSurface(fill: fill, ink: ink, inkMuted: ink.opacity(0.62))
    }
}

enum TabPane {
    case content
    case sunken

    var surface: TabSurface {
        switch self {
        case .content: .pane(Palette.surface)
        case .sunken: .pane(Palette.surfaceSunken)
        }
    }
}

struct TabStrip<Leading: View, Tabs: View, Append: View, Trailing: View>: View {
    var pane: TabPane
    var selection: AnyHashable?
    var tabCount: Int = 0
    var leading: Leading
    var tabs: Tabs
    var append: Append
    var trailing: Trailing

    @State private var width: CGFloat = 0
    @State private var tabsWidth: CGFloat?
    @State private var overflow = TabStripOverflow()
    @State private var stripWidth: CGFloat = 0
    @State private var leadingWidth: CGFloat = 0
    @State private var appendWidth: CGFloat = 0
    @State private var trailingWidth: CGFloat = 0

    private var tabWidth: CGFloat? {
        guard tabCount > 0, stripWidth > 0 else { return nil }
        let room = stripWidth - leadingWidth - appendWidth - trailingWidth - TabStripTrack.margin * 2
        guard room > 0 else { return nil }
        return max(room / CGFloat(tabCount), TabPill.minimumWidth).rounded(.down)
    }

    init(
        pane: TabPane = .content,
        selection: AnyHashable? = nil,
        tabCount: Int = 0,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder tabs: () -> Tabs,
        @ViewBuilder append: () -> Append,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.pane = pane
        self.selection = selection
        self.tabCount = tabCount
        self.leading = leading()
        self.tabs = tabs()
        self.append = append()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                leading
                    .onGeometryChange(for: CGFloat.self) { $0.size.width.rounded(.up) } action: {
                        leadingWidth = $0
                    }

                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        tabs
                            .onGeometryChange(for: CGFloat.self) { $0.size.width.rounded(.up) } action: {
                                tabsWidth = $0
                            }
                    }
                    .scrollIndicators(.never)
                    .frame(maxWidth: tabWidth == nil ? (tabsWidth ?? .infinity) : .infinity)
                    .environment(\.tabItemWidth, tabWidth)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width.rounded() } action: { width = $0 }
                    .onScrollGeometryChange(for: TabStripOverflow.self, of: Self.measure) { _, new in
                        overflow = new
                    }
                    .mask { fade }
                    .onChange(of: selection, initial: true) { _, _ in reveal(proxy) }
                    .onChange(of: width) { _, _ in reveal(proxy) }
                }

                append
                    .onGeometryChange(for: CGFloat.self) { $0.size.width.rounded(.up) } action: {
                        appendWidth = $0
                    }
            }
            .background {
                Color.clear
                    .glassEffect(
                        .regular,
                        in: RoundedRectangle(cornerRadius: TabStripTrack.corner, style: .continuous)
                    )
                    .padding(.vertical, TabStripTrack.margin)
            }
            .padding(.leading, TabStripTrack.margin)

            if tabWidth == nil {
                Spacer(minLength: 0)
            }

            trailing
                .onGeometryChange(for: CGFloat.self) { $0.size.width.rounded(.up) } action: {
                    trailingWidth = $0
                }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width.rounded() } action: { measured in
            if measured > 0 { stripWidth = measured }
        }
        .frame(height: TabPill.barHeight)
        .tabStripMaterial()
    }
}

extension EnvironmentValues {
    @Entry var tabItemWidth: CGFloat?
}

enum TabPill {
    static let barHeight: CGFloat = 36

    static let margin: CGFloat = 4

    static let contentInset: CGFloat = 14

    static let minimumWidth: CGFloat = 92

    static func shape() -> Capsule { Capsule(style: .continuous) }
}

enum TabStripTrack {
    static let margin: CGFloat = 3
    static let corner: CGFloat = Metrics.corner
}

extension TabStrip {
    @ViewBuilder
    private var fade: some View {
        if TabStripFade.isDrawn(tabsWidth: tabsWidth, stripWidth: width) {
            let step = TabStripFade.step(stripWidth: width)
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: overflow.leading ? step : 0),
                    .init(color: .black, location: overflow.trailing ? 1 - step : 1),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            Color.black
        }
    }

    private static func measure(_ scroll: ScrollGeometry) -> TabStripOverflow {
        TabStripOverflow(
            leading: scroll.contentOffset.x > 1,
            trailing: scroll.contentOffset.x + scroll.containerSize.width
                < scroll.contentSize.width - 1
        )
    }

    private func reveal(_ proxy: ScrollViewProxy) {
        guard let selection else { return }
        Task { @MainActor in
            await Task.yield()
            proxy.scrollTo(selection, anchor: nil)
        }
    }
}

extension TabStrip where Leading == EmptyView {
    init(
        pane: TabPane = .content,
        selection: AnyHashable? = nil,
        tabCount: Int = 0,
        @ViewBuilder tabs: () -> Tabs,
        @ViewBuilder append: () -> Append,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            pane: pane, selection: selection, tabCount: tabCount,
            leading: { EmptyView() }, tabs: tabs, append: append, trailing: trailing
        )
    }
}

extension TabStrip where Trailing == EmptyView {
    init(
        pane: TabPane = .content,
        selection: AnyHashable? = nil,
        tabCount: Int = 0,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder tabs: () -> Tabs,
        @ViewBuilder append: () -> Append
    ) {
        self.init(
            pane: pane, selection: selection, tabCount: tabCount,
            leading: leading, tabs: tabs, append: append, trailing: { EmptyView() }
        )
    }
}

struct TabStripOverflow: Equatable {
    var leading = false
    var trailing = false
}

struct TabStripSeparator: View {
    var isHidden = false

    var body: some View {
        Rectangle()
            .fill(Palette.border.opacity(0.7))
            .frame(width: Metrics.hairline, height: Metrics.barHeight / 2)
            .opacity(isHidden ? 0 : 1)
    }
}
