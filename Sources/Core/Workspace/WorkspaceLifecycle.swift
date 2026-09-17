import Foundation

public extension Workspace {
    mutating func archive(at date: Date = Date()) {
        state = .archived
        archivedAt = date
    }

    mutating func restore(to path: String, hasSetupScript: Bool) {
        state = .active
        archivedAt = nil
        self.path = path
        apply(.worktreeRebuilt(hasSetupScript: hasSetupScript))
    }
}
