import Foundation

public struct PendingWorkspace: Identifiable, Sendable, Hashable {
    public var id: WorkspaceID
    public var repoID: RepoID
    public var name: String

    public init(id: WorkspaceID, repoID: RepoID, name: String) {
        self.id = id
        self.repoID = repoID
        self.name = name
    }
}
