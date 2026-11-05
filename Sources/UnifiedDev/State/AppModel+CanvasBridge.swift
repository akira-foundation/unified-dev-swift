import Core

extension AppModel {
    func showCanvasForBridge(_ order: CanvasShowOrder, in workspaceID: WorkspaceID) async -> CanvasShowOutcome {
        guard let model = paneTarget(workspaceID) else { return .refused(Self.noWorkspaceForPane) }
        let target: CanvasShowTarget
        switch CanvasFile.showing(order, worktree: model.workspace.path) {
        case .failure(let refusal): return .refused(refusal.sentence)
        case .success(let found): target = found
        }
        model.noteCanvasShown(path: target.absolute, by: order.caller)
        let relative = target.relative

        let store = CenterTabStore.shared
        let tabs = WorkspaceTabsStore.shared
        let front = tabs.selectedTab(in: model)
        let activeSession = model.activeSessionID
        let placement = CanvasPlacement.decide(
            hasCanvas: store.canvas(for: workspaceID) != nil,
            focus: order.focus,
            hasCaller: order.caller != nil,
            hasTabInFront: front != nil
        )

        let canvas = store.showCanvas(path: relative, title: order.title, workspaceID: workspaceID)
        let content = PaneContent.tool(canvas.id)
        let shown: (String) -> CanvasShowOutcome = { .shown("Showing '\(relative)' in the canvas\($0)\(target.followUp)") }

        switch placement {
        case .retarget(let bringToFront):
            guard bringToFront else { return shown(", which stays where it was.") }
            tabs.reveal(content, in: model, focusing: true)
            return shown(", brought to the front.")
        case .besideCaller:
            if let caller = order.caller, splitCanvas(content, besideChat: caller, in: model) {
                return shown(", to the right of this chat.")
            }
            tabs.select(content, in: model)
            return shown(", in a new tab in front.")
        case .newTab(let inFront):
            if inFront {
                tabs.select(content, in: model)
                return shown(", in a new tab in front.")
            }
            if model.activeSessionID != activeSession { model.activeSessionID = activeSession }
            if let front { tabs.select(front, in: model) }
            return shown(", in a new tab behind the one in front.")
        }
    }

    private func splitCanvas(_ content: PaneContent, besideChat caller: SessionID, in model: WorkspaceModel) -> Bool {
        let tabs = WorkspaceTabsStore.shared
        let entries = tabs.entries(in: model)
        guard let destination = PaneSplitAnchor.chat(caller).resolve(
            in: paneSplitSnapshots(of: entries),
            selected: tabs.selectedTab(in: model, entries: entries)
        ), tabs.split(tab: destination.tab, pane: destination.pane, axis: .horizontal, showing: content) != nil
        else { return false }
        tabs.select(destination.tab, in: model)
        return true
    }
}
