import Core

extension AppModel {
    func workspaceTabsForBridge(_ workspaceID: WorkspaceID) async -> WorkspaceTabCensus? {
        guard let model = paneTarget(workspaceID) else { return nil }
        return WorkspaceTabCensus(tabs: await tabRows(in: model).map { $0.report })
    }

    private func tabRows(
        in model: WorkspaceModel
    ) async -> [(content: PaneContent, report: WorkspaceTabReport)] {
        let tabs = WorkspaceTabsStore.shared
        let entries = tabs.entries(in: model)
        let active = tabs.selectedTab(in: model, entries: entries)
        let numbers = browserNumbers(in: model)

        var rows: [(content: PaneContent, report: WorkspaceTabReport)] = []
        for entry in entries {
            guard let root = await detail(of: entry, in: model, numbers: numbers) else { continue }
            let layout = tabs.layout(of: entry)
            let panes = layout.paneCount > 1
                ? layout.panes.compactMap {
                    pane(tabs.content(of: $0, in: entry), in: model, numbers: numbers)
                }
                : []

            rows.append((
                entry,
                WorkspaceTabReport(
                    number: 0,
                    title: CenterTabStore.shared.title(of: entry, in: model),
                    isActive: entry == active,
                    detail: root,
                    panes: panes
                )
            ))
        }

        for index in rows.indices { rows[index].report.number = index + 1 }
        return rows
    }

    func selectWorkspaceTabForBridge(
        _ choice: WorkspaceTabChoice, in workspaceID: WorkspaceID
    ) async -> WorkspaceTabSelection {
        guard let model = paneTarget(workspaceID) else {
            return .refused(WorkspaceTabTrouble.noWorkspace)
        }
        let rows = await tabRows(in: model)

        let chosen: WorkspaceTabReport
        switch WorkspaceTabChoice.choose(choice, among: rows.map { $0.report }) {
        case .failure(let refusal): return .refused(refusal.sentence)
        case .success(let found): chosen = found
        }
        guard let row = rows.first(where: { $0.report.number == chosen.number }) else {
            return .refused(WorkspaceTabTrouble.noWorkspace)
        }

        if let answer = WorkspaceTabSelection.withoutMoving(chosen) { return answer }

        WorkspaceTabsStore.shared.select(row.content, in: model)
        return .brought(chosen)
    }

    private func detail(
        of content: PaneContent, in model: WorkspaceModel, numbers: [String: Int]
    ) async -> WorkspaceTabDetail? {
        switch content {
        case .chat(let sessionID):
            guard let session = model.sessions.first(where: { $0.id == sessionID }) else {
                return nil
            }
            var messages = 0
            if let store {
                messages = (try? await store.messageCount(sessionID: sessionID)) ?? 0
            }
            return .chat(
                WorkspaceTabChat(agent: session.agentKind, state: session.state, messages: messages)
            )

        case .tool(let id):
            let centre = CenterTabStore.shared
            guard let tab = centre.tabs(for: model.workspace.id).first(where: { $0.id == id })
            else { return nil }

            switch tab.kind {
            case .terminal:
                return .terminal(
                    WorkspaceTabTerminal(
                        directory: FolderTerminal.launchDirectory(
                            requested: tab.directory, root: model.workspace.path
                        ),
                        isLive: TerminalSplitStore.shared.panes(of: tab.id).contains {
                            TerminalSessionStore.shared.hasShell(paneID: $0)
                        }
                    )
                )

            case .review:
                return .review(WorkspaceTabReview(file: tab.path))

            case .notes:
                var characters = 0
                if let store {
                    let note = try? await store.note(workspaceID: model.workspace.id)
                    characters = note?.body.count ?? 0
                }
                return .notes(WorkspaceTabNote(characters: characters))

            case .browser:
                guard let number = numbers[tab.id] else { return nil }
                return .browser(
                    report(tab, number: number, name: centre.displayTitle(of: tab, in: model))
                )
            }
        }
    }

    private func pane(
        _ content: PaneContent, in model: WorkspaceModel, numbers: [String: Int]
    ) -> WorkspaceTabPane? {
        let title = CenterTabStore.shared.title(of: content, in: model)
        switch content {
        case .chat(let sessionID):
            guard model.sessions.contains(where: { $0.id == sessionID }) else { return nil }
            return WorkspaceTabPane(kind: .chat, title: title)

        case .tool(let id):
            let centre = CenterTabStore.shared
            guard let tab = centre.tabs(for: model.workspace.id).first(where: { $0.id == id })
            else { return nil }
            return WorkspaceTabPane(
                kind: PaneCensusKind(tab.kind),
                title: title,
                browser: tab.kind == .browser ? numbers[tab.id] : nil
            )
        }
    }
}
