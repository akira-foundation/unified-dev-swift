import Foundation
import QuartzCore
import Core

@MainActor
enum SwitchTrace {
    static var isEnabled = false

    struct Mark: Sendable {
        var name: String
        var ms: Double
        var onScreen: Bool
    }

    private(set) static var marks: [Mark] = []
    private(set) static var workspaceID: WorkspaceID?
    private static var start: CFTimeInterval = 0
    private static var seen: Set<String> = []
    private static var pendingOnScreen: [String] = []

    static func begin(workspaceID id: WorkspaceID) {
        guard isEnabled else { return }
        marks = []
        seen = []
        pendingOnScreen = []
        workspaceID = id
        start = CACurrentMediaTime()
    }

    static func mark(_ name: String, workspace id: WorkspaceID? = nil) {
        guard isEnabled, start > 0 else { return }
        if let id, id != workspaceID { return }
        guard seen.insert(name).inserted else { return }
        marks.append(Mark(name: name, ms: (CACurrentMediaTime() - start) * 1000, onScreen: false))
    }

    static func markOnScreen(_ name: String, workspace id: WorkspaceID? = nil) {
        guard isEnabled, start > 0 else { return }
        if let id, id != workspaceID { return }
        guard !seen.contains(name + ".onscreen") else { return }
        pendingOnScreen.append(name)
    }

    static func tick() {
        guard isEnabled, start > 0, !pendingOnScreen.isEmpty else { return }
        let ms = (CACurrentMediaTime() - start) * 1000
        for name in pendingOnScreen {
            guard seen.insert(name + ".onscreen").inserted else { continue }
            marks.append(Mark(name: name + ".onscreen", ms: ms, onScreen: true))
        }
        pendingOnScreen.removeAll()
    }

    static func timeline() -> JSONValue {
        .array(
            marks
                .sorted { $0.ms < $1.ms }
                .map {
                    .object([
                        "name": .string($0.name),
                        "ms": .number($0.ms),
                        "onScreen": .bool($0.onScreen),
                    ])
                }
        )
    }
}
