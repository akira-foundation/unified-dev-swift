import Foundation

public struct UnfinishedRun: Sendable, Hashable {
    public let status: Int32
    public let stderr: String
    public let command: String
    public let leftATurnOpen: Bool

    public init(status: Int32, stderr: String, command: String, leftATurnOpen: Bool) {
        self.status = status
        self.stderr = stderr
        self.command = command
        self.leftATurnOpen = leftATurnOpen
    }

    public static func of(
        status: Int32,
        sawResult: Bool,
        state: SessionState,
        stderr: String,
        command: String
    ) -> UnfinishedRun? {
        if state.isMidTurn {
            return UnfinishedRun(status: status, stderr: stderr, command: command, leftATurnOpen: true)
        }
        guard status != 0 else { return nil }
        guard !sawResult || ModelRefusal.model(inStderr: stderr) != nil else { return nil }
        return UnfinishedRun(status: status, stderr: stderr, command: command, leftATurnOpen: false)
    }

    public var wasSilent: Bool {
        leftATurnOpen && status == 0 && stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var subtype: String { wasSilent ? Self.abandonedSubtype : Self.exitSubtype }

    public static let abandonedSubtype = "turn_abandoned"
    public static let exitSubtype = "process_exit"

    public var message: String {
        guard !wasSilent else { return Self.silentSentence }
        let opening = "The agent exited with status \(status)."
        let tail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return tail.isEmpty ? opening : "\(opening)\n\(stderr)"
    }

    public static let silentSentence = "The agent's process ended in the middle of this turn."

    public var payload: Data {
        (try? JSONEncoder().encode(Stored(
            subtype: subtype, status: Int(status), stderr: stderr, command: command
        ))) ?? Data(#"{"type":"error"}"#.utf8)
    }

    private struct Stored: Encodable {
        let type = "error"
        let subtype: String
        let status: Int
        let stderr: String
        let command: String
    }
}
