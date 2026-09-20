import Foundation

public enum BridgeOwnerPlacement {
    public static func refusal(workingDirectory: String?, workspaces: [Workspace]) -> String? {
        guard let workingDirectory, !workingDirectory.isEmpty else { return nil }
        let directory = standardised(workingDirectory)
        guard let workspace = workspaces.first(where: { holds(directory, workspace: $0) }) else {
            return nil
        }
        return """
            This is the owner's own registration of Unified Dev, and it was started inside the \
            Unified Dev workspace '\(workspace.name)' at \(workspace.path). An agent working in a \
            workspace uses the bridge Unified Dev gives that workspace, not the owner's, so this \
            connection was refused. To use the owner's tools, run the client from a directory \
            outside Unified Dev's workspaces.
            """
    }

    private static func holds(_ directory: String, workspace: Workspace) -> Bool {
        guard workspace.state != .archived, !workspace.path.isEmpty else { return false }
        let root = standardised(workspace.path)
        return directory == root || directory.hasPrefix(root + "/")
    }

    private static func standardised(_ path: String) -> String {
        let standard = ((path as NSString).standardizingPath as NSString).resolvingSymlinksInPath
        return standard.count > 1 && standard.hasSuffix("/") ? String(standard.dropLast()) : standard
    }
}
