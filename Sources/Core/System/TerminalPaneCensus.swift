import Foundation

public enum TerminalPaneCensus {
    public struct Census: Sendable, Equatable {
        public var panes: Set<String>
        public var doubtful: Set<WorkspaceID>

        public init(panes: Set<String> = [], doubtful: Set<WorkspaceID> = []) {
            self.panes = panes
            self.doubtful = doubtful
        }
    }

    private struct Tab: Decodable {
        var id: String
        var kind: String
    }

    private static let terminalKind = "terminal"

    public static func terminalTabs(of workspace: WorkspaceID, in defaults: UserDefaults) -> [String]? {
        guard let data = defaults.data(forKey: TabDefaults.tabListKey(workspace)) else { return [] }
        guard let tabs = try? JSONDecoder().decode([Tab].self, from: data) else { return nil }
        return tabs.filter { $0.kind == terminalKind }.map(\.id)
    }

    public static func panes(ofTab tab: String, in defaults: UserDefaults) -> [String]? {
        guard let encoded = defaults.string(forKey: TabDefaults.splitKey(tab)) else { return [tab] }
        guard let layout = SplitLayout(encoded: encoded) else { return nil }
        return layout.panes
    }

    public static func census(of workspaces: [WorkspaceID], in defaults: UserDefaults) -> Census {
        var census = Census()
        for workspace in workspaces {
            guard let tabs = terminalTabs(of: workspace, in: defaults) else {
                census.doubtful.insert(workspace)
                continue
            }
            for tab in tabs {
                guard let panes = panes(ofTab: tab, in: defaults) else {
                    census.doubtful.insert(workspace)
                    continue
                }
                census.panes.formUnion(panes)
            }
        }
        return census
    }
}
