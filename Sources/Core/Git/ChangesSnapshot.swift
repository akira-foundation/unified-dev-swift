import Foundation

public struct ChangesSnapshot: Sendable, Equatable {
    public var files: [ChangedFile]
    public var revisions: [String: String]
    public var scope: DiffScope

    public init(files: [ChangedFile], revisions: [String: String], scope: DiffScope) {
        self.files = files
        self.revisions = revisions
        self.scope = scope
    }

    public static func advancesGeneration(from previous: ChangesSnapshot?, to next: ChangesSnapshot) -> Bool {
        previous != next
    }
}
