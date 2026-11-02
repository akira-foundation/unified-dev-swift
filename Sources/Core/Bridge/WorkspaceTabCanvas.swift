import Foundation

public struct WorkspaceTabCanvas: Sendable, Equatable {
    public var path: String

    public init(path: String) {
        self.path = path
    }

    public var json: JSONValue {
        .object(["path": .string(path)])
    }
}
