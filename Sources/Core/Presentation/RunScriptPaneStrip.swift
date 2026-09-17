import Foundation

public enum RunScriptPaneStrip: Sendable, Hashable {
    case none
    case restart(command: String)
    case stopped(caption: String, command: String)

    public static func decide(
        offer: String?, activity: RunScriptActivity.State, script: RunScript?
    ) -> RunScriptPaneStrip {
        guard let script else { return offer.map { .restart(command: $0) } ?? .none }
        let command = script.command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return .none }

        switch activity {
        case .running:
            return .none
        case .stopped(let after):
            return .stopped(caption: caption(after: after), command: command)
        case .idle:
            return offer == nil ? .none : .restart(command: command)
        }
    }

    public static func caption(after length: Duration?) -> String {
        guard let length else { return "Stopped" }
        return "Stopped after \(format(length))"
    }

    public static func format(_ length: Duration) -> String {
        let seconds = Int(length.components.seconds)
        guard seconds >= 1 else { return "under a second" }
        guard seconds >= 60 else { return "\(seconds)s" }
        let minutes = seconds / 60
        guard minutes >= 60 else { return "\(minutes)m \(seconds % 60)s" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}
