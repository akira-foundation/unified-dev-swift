import Observation
import Core

@MainActor
@Observable
final class TabRenameField {
    static let shared = TabRenameField()

    private var renaming: [WorkspaceID: String] = [:]

    func id(in workspaceID: WorkspaceID, among entries: [PaneContent]) -> String? {
        TabRenaming.openField(renaming[workspaceID], among: entries)
    }

    func begin(_ id: String, in workspaceID: WorkspaceID) {
        renaming[workspaceID] = id
    }

    func end(in workspaceID: WorkspaceID) {
        renaming[workspaceID] = nil
    }
}
