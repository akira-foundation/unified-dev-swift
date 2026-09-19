public struct TabRenameState: Sendable, Equatable {
    private var renaming: [WorkspaceID: String] = [:]
    private var drafts: [WorkspaceID: String] = [:]

    public init() {}

    public func id(in workspaceID: WorkspaceID, among entries: [PaneContent]) -> String? {
        TabRenaming.openField(renaming[workspaceID], among: entries)
    }

    public func draft(in workspaceID: WorkspaceID) -> String? {
        guard renaming[workspaceID] != nil else { return nil }
        return drafts[workspaceID]
    }

    public mutating func begin(_ id: String, in workspaceID: WorkspaceID) {
        renaming[workspaceID] = id
        drafts[workspaceID] = nil
    }

    public mutating func keepDraft(_ text: String, in workspaceID: WorkspaceID) {
        guard renaming[workspaceID] != nil else { return }
        drafts[workspaceID] = text
    }

    public mutating func end(in workspaceID: WorkspaceID) {
        renaming[workspaceID] = nil
        drafts[workspaceID] = nil
    }
}
