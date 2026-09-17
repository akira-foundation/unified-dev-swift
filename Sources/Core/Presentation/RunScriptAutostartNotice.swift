import Foundation

public struct RunScriptAutostartNotice: Sendable, Hashable {
    public struct Line: Sendable, Hashable, Identifiable {
        public var script: RunScript
        public var approved: String?

        public var id: String { script.id }
        public var name: String { script.name }
        public var command: String { script.command }
    }

    public var title: String
    public var lines: [Line]
    public var allowTitle: String
    public var scripts: [RunScript]

    public static func make(project: String, decision: RunScriptAutostart) -> RunScriptAutostartNotice? {
        guard case .ask(let scripts, let changes) = decision else { return nil }
        let allow = "Allow for \(project)"

        guard changes.contains(where: { $0.approved != nil }) else {
            let asking = changes.isEmpty ? scripts : changes.map(\.script)
            let count = asking.count == 1 ? "1 run script" : "\(asking.count) run scripts"
            return RunScriptAutostartNotice(
                title: "\(project) wants to start \(count) when a workspace opens",
                lines: asking.map { Line(script: $0, approved: nil) },
                allowTitle: allow,
                scripts: scripts
            )
        }

        let title = changes.count == 1
            ? "A run script changed since you allowed it"
            : "\(changes.count) run scripts changed since you allowed them"
        return RunScriptAutostartNotice(
            title: title,
            lines: changes.map { Line(script: $0.script, approved: $0.approved) },
            allowTitle: allow,
            scripts: scripts
        )
    }
}
