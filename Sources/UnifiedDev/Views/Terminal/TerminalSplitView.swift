import SwiftUI
import AppKit
import Core

struct TerminalSplitView: View {
    var ownerID: String
    var workspace: Workspace
    var repo: Repo?
    var port: Int
    var directory: String = ""
    var runScript: RunScript?
    var onCloseTab: @MainActor () -> Void
    var splitColumn: @MainActor (SplitAxis, PaneKind) -> Void
    var terminalLabel: String = "Terminal"
    var onAddToChat: (@MainActor (TerminalExcerpt) -> Void)?

    @AppStorage(TerminalGhostty.defaultsKey) private var usesGhosttyTheme = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var splits: TerminalSplitStore { .shared }

    private static let dividerThickness: Double = 1

    private static let paneInset: CGFloat = Metrics.spacingSmall

    var body: some View {
        let layout = splits.layout(for: ownerID)
        let focusRequest = splits.focusRequest(for: ownerID)
        let remembered = TerminalSessionStore.shared.recall.offers(inPanes: layout.panes)
        let activity = runScript == nil
            ? RunScriptActivity.State.idle
            : TerminalSessionStore.shared.activity.state(inPane: ownerID)

        return GeometryReader { proxy in
            let geometry = layout.geometry(in: proxy.size, dividerThickness: Self.dividerThickness)

            ZStack(alignment: .topLeading) {
                if proxy.size.width > 1, proxy.size.height > 1 {
                    ForEach(geometry.panes, id: \.pane) { item in
                        pane(
                            item.pane,
                            in: layout,
                            focusRequest: focusRequest,
                            strip: RunScriptPaneStrip.decide(
                                offer: remembered[item.pane],
                                activity: item.pane == ownerID ? activity : .idle,
                                script: item.pane == ownerID ? runScript : nil
                            )
                        )
                            .frame(width: item.frame.width, height: item.frame.height)
                            .position(x: item.frame.midX, y: item.frame.midY)
                    }

                    ForEach(geometry.dividers, id: \.path) { divider in
                        SplitPaneDivider(
                            axis: divider.axis,
                            ratio: divider.ratio,
                            span: divider.span,
                            length: divider.axis == .horizontal
                                ? divider.frame.height
                                : divider.frame.width,
                            color: dividerColor,
                            onChange: { ratio in
                                splits.setRatio(ratio, at: divider.path, in: ownerID)
                            },
                            onChangeEnded: { splits.persistRatio(in: ownerID) }
                        )
                        .position(x: divider.frame.midX, y: divider.frame.midY)
                    }
                }
            }
        }
    }

    private func pane(
        _ id: String, in layout: SplitLayout, focusRequest: Int, strip: RunScriptPaneStrip
    ) -> some View {
        let isFocused = layout.focus == id
        let sessions = TerminalSessionStore.shared

        return VStack(spacing: 0) {
            switch strip {
            case .none:
                EmptyView()
            case let .restart(command):
                TerminalRestartStrip(
                    command: command,
                    onStart: { sessions.startRemembered(command, inPane: id) },
                    onDismiss: { sessions.dismissRemembered(inPane: id) }
                )
            case let .stopped(caption, command):
                RunScriptStoppedStrip(
                    caption: caption,
                    command: command,
                    onRunAgain: { _ = sessions.retype(command, inPane: id) },
                    onCloseTab: onCloseTab,
                    onDismiss: { sessions.activity.dismiss(inPane: id) }
                )
            }

            TerminalView(
                tab: TerminalTab(id: TerminalTabID(id), workspaceID: workspace.id, title: "Terminal"),
                workspace: workspace,
                repo: repo,
                port: port,
                directory: directory,
                isFocusedPane: isFocused,
                focusRequest: focusRequest,
                onFocus: { splits.focus(id, in: ownerID) },
                onCommand: { handle($0, from: id) },
                onExit: { finished($0, in: id) },
                onContextMenu: {
                    let excerpt = TerminalSessionStore.shared.excerpt(
                        inPaneID: id, workspaceID: workspace.id, label: terminalLabel
                    )
                    let add: (@MainActor () -> Void)? = if let excerpt, let onAddToChat {
                        { onAddToChat(excerpt) }
                    } else { nil }
                    return TerminalPaneMenu.make(
                        canClose: layout.paneCount > 1,
                        isZoomed: layout.zoomed == id,
                        onAddToChat: add
                    ) { _ = handle($0, from: id) }
                }
            )
            .padding(Self.paneInset)
        }
        .animation(reduceMotion ? nil : Motion.pane, value: strip)
        .overlay {
            if !isFocused && layout.paneCount > 1 { dimming }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(isFocused ? "Terminal pane, focused" : "Terminal pane")
    }

    private var dimming: some View {
        let ghostty = usesGhosttyTheme ? TerminalGhostty.splitAppearance() : GhosttySplitAppearance()
        let opacity = ghostty.unfocusedOpacity ?? 0.8
        let fill = ghostty.unfocusedFill.map { Color(nsColor: NSColor($0)) } ?? Palette.surfaceSunken

        return fill
            .opacity(1 - opacity)
            .allowsHitTesting(false)
    }

    private var dividerColor: Color {
        guard usesGhosttyTheme, let color = TerminalGhostty.splitAppearance().dividerColor else {
            return Palette.border
        }
        return Color(nsColor: NSColor(color))
    }

    private func finished(_ exit: TerminalExit, in pane: String) {
        guard exit.closesPane else { return }
        close(pane)
    }

    private func close(_ pane: String) {
        guard splits.close(pane: pane, in: ownerID) else {
            onCloseTab()
            return
        }
        TerminalSessionStore.shared.closePane(id: pane)
    }

    private func handle(_ command: TerminalPaneCommand, from pane: String) -> Bool {
        splits.focus(pane, in: ownerID)

        switch command {
        case .split(let axis, .terminal):
            return splits.split(ownerID, axis: axis) != nil

        case .split(let axis, let kind):
            splitColumn(axis, kind)
            return true

        case .focus(let direction):
            return splits.moveFocus(direction, in: ownerID)

        case .close:
            close(pane)
            return true

        case .toggleZoom:
            return splits.toggleZoom(in: ownerID)
        }
    }
}
