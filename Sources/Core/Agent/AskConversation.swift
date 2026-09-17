import Foundation

public enum AskConversation {
    public static let title = "Ask Unified Dev"

    public static let instructions = """
    You are Ask Unified Dev, running inside the Unified Dev macOS app. Unified Dev manages the user's projects, \
    workspaces and agent conversations. This conversation belongs to Unified Dev and has no workspace \
    of its own.

    When the user asks to create, open, inspect or manage projects or workspaces, use Unified Dev by \
    default unless they explicitly name another app. Use the connected Unified Dev MCP tools. Discover \
    them with tool search if needed: project_list and workspace_list find existing work, \
    project_add registers a repository, and workspace_start creates a workspace and starts its \
    agent with the supplied prompt. Include any requested exploration or implementation in that \
    opening prompt, and let Unified Dev choose its configured workspace directory.

    Do not select Conductor or another workspace manager merely because its skill is installed \
    or mentioned in past context. If Unified Dev's tools are unavailable or fail, report the problem \
    instead of silently creating workspaces elsewhere. Follow the current permission mode and \
    any approval requests from the tools.
    """

    public static let placeholder = "Ask about your projects and workspaces, or ask for one"

    public static let permissionMode = PermissionMode.auto

    public static func directory(besideDatabaseAt databasePath: String) -> String {
        let container = (databasePath as NSString).deletingLastPathComponent
        return (container as NSString).appendingPathComponent("Ask")
    }

    public static func prepareDirectory(besideDatabaseAt databasePath: String) -> String? {
        let path = directory(besideDatabaseAt: databasePath)
        do {
            try FileManager.default.createDirectory(
                atPath: path,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            return path
        } catch {
            return nil
        }
    }

    public static func modeOnOpening(
        stored: PermissionMode,
        isFirstOpenSinceLaunch: Bool
    ) -> PermissionMode? {
        guard isFirstOpenSinceLaunch, stored != permissionMode else { return nil }
        return permissionMode
    }

    public static func newSession(sortOrder: Int = 0) -> Session {
        Session(
            workspaceID: nil,
            title: title,
            permissionMode: permissionMode,
            sortOrder: sortOrder
        )
    }

    public static let emptyHeading = "Ask Unified Dev anything about your work"
    public static let emptyDetail =
        "Start a new project or a workspace, ask what is running and what needs you, "
        + "find the workspace with the failing checks, and open it."
}
