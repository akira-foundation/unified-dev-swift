import Foundation

public struct RevertMenuEntry: Equatable, Sendable {
    public let title: String
    public let isEnabled: Bool
    public let note: String?
}

extension FileBarControls {
    public static func revertMenuEntry(filename: String, blocker: String?) -> RevertMenuEntry {
        let control = revert(filename: filename, blocker: blocker)
        return RevertMenuEntry(title: control.title, isEnabled: blocker == nil, note: blocker.map { _ in control.hint })
    }
}
