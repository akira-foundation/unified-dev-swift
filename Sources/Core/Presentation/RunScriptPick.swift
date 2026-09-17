import Foundation

public enum RunScriptPick<Tab: Sendable & Hashable>: Sendable, Hashable {
    case focus(Tab)
    case rerun(Tab)
    case open

    public static func decide(
        runScript: String, tabs: [Tab], scriptOf: (Tab) -> String?, isRunning: (Tab) -> Bool
    ) -> RunScriptPick {
        let carrying = tabs.filter { scriptOf($0) == runScript }
        if let live = carrying.first(where: isRunning) { return .focus(live) }
        if let stopped = carrying.first { return .rerun(stopped) }
        return .open
    }
}
