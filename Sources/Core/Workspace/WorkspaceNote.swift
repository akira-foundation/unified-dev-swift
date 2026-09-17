import Foundation

public struct WorkspaceNote: Sendable, Hashable {
    public var workspaceID: WorkspaceID
    public var body: String
    public var updatedAt: Date

    public init(workspaceID: WorkspaceID, body: String, updatedAt: Date = Date()) {
        self.workspaceID = workspaceID
        self.body = body
        self.updatedAt = updatedAt
    }

    public static let autosaveDelay: Duration = .milliseconds(750)

    public static func needsSave(stored: String, typed: String) -> Bool {
        storable(typed) != storable(stored)
    }

    public static func storable(_ body: String) -> String {
        body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : body
    }

    public static let unreadable = """
        This note could not be read out of Unified Dev's database, so it is not being shown and \
        cannot be edited.

        Nothing has been lost: it is still in the row it was in.

        Try again, and if that fails too, quit Unified Dev and open it again.
        """

    public static let unwritable = "Not saved. Unified Dev's database refused the write. Retried as you type."
}
