import Foundation

public enum TerminalStartDecision: Sendable, Equatable {
    case inProcess
    case attach(session: String)
    case createFresh(session: String)

    public var session: String? {
        switch self {
        case .inProcess: nil
        case .attach(let name), .createFresh(let name): name
        }
    }
}

public enum TmuxSessions {
    public static let sessionPrefix = "ud"

    private static let separator: Character = "_"

    public static func sessionName(workspaceID: WorkspaceID, paneID: String) -> String {
        [sessionPrefix, sanitized(workspaceID.rawValue), sanitized(paneID)].joined(separator: String(separator))
    }

    public static func paneID(ofSessionName name: String) -> String? {
        parts(of: name)?.pane
    }

    public static func workspaceID(ofSessionName name: String) -> String? {
        parts(of: name)?.workspace
    }

    public static func isAppSession(_ name: String) -> Bool {
        parts(of: name) != nil
    }

    private static func parts(of name: String) -> (workspace: String, pane: String)? {
        let fields = name.split(separator: separator, omittingEmptySubsequences: false)
        guard fields.count == 3, fields[0] == sessionPrefix,
              !fields[1].isEmpty, !fields[2].isEmpty else { return nil }
        return (String(fields[1]), String(fields[2]))
    }

    private static func sanitized(_ id: String) -> String {
        let safe = id.unicodeScalars.map { scalar -> Character in
            let isSafe = (scalar >= "a" && scalar <= "z")
                || (scalar >= "A" && scalar <= "Z")
                || (scalar >= "0" && scalar <= "9")
                || scalar == "-"
            return isSafe ? Character(scalar) : "-"
        }
        return String(safe)
    }

    public static func socketName(databasePath: String) -> String {
        "unifieddev-" + fingerprint(databasePath)
    }

    static func fingerprint(_ value: String) -> String {
        var hash: UInt32 = 2_166_136_261
        for byte in value.utf8 {
            hash ^= UInt32(byte)
            hash &*= 16_777_619
        }
        return String(format: "%08x", hash)
    }

    public static func decide(
        workspaceID: WorkspaceID,
        paneID: String,
        persistenceEnabled: Bool,
        tmuxAvailable: Bool,
        existingSessions: Set<String>
    ) -> TerminalStartDecision {
        guard persistenceEnabled, tmuxAvailable else { return .inProcess }
        let name = sessionName(workspaceID: workspaceID, paneID: paneID)
        return existingSessions.contains(name) ? .attach(session: name) : .createFresh(session: name)
    }

    public static func reachablePanes(_ panes: Set<String>, persistenceEnabled: Bool) -> Set<String> {
        persistenceEnabled ? panes : []
    }

    public static func orphans(
        sessions: [String], livePaneIDs: Set<String>, sparing sparedWorkspaces: Set<WorkspaceID>
    ) -> [String] {
        let live = Set(livePaneIDs.map(sanitized))
        let spared = Set(sparedWorkspaces.map { sanitized($0.rawValue) })
        return sessions.filter { name in
            guard let parts = parts(of: name), !spared.contains(parts.workspace) else { return false }
            return !live.contains(parts.pane)
        }
    }

    public static func sessions(ofWorkspace workspace: WorkspaceID, in sessions: [String]) -> [String] {
        let owner = sanitized(workspace.rawValue)
        return sessions.filter { workspaceID(ofSessionName: $0) == owner }
    }

    public static func parsePanePIDs(_ output: String) -> [String: Int32] {
        var pids: [String: Int32] = [:]
        for line in output.split(separator: "\n") {
            let fields = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard fields.count == 2, let pid = Int32(fields[0]) else { continue }
            let session = fields[1].trimmingCharacters(in: .whitespaces)
            guard !session.isEmpty, pids[session] == nil else { continue }
            pids[session] = pid
        }
        return pids
    }

    public static func parseSessionList(_ output: String) -> [String] {
        output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    public static func configuration(defaultShell: String) -> String {
        """
        # Written by Unified Dev on every launch. Edits will be overwritten.
        #
        # This file configures a private tmux server that holds one shell per Unified Dev terminal pane.
        # It is not your tmux configuration and does not affect your own sessions.

        set -g default-shell "\(defaultShell)"
        set -g default-terminal "xterm-256color"
        set -ga terminal-features ",xterm-256color:RGB"
        set -g escape-time 0
        set -g history-limit 50000
        set -g status off
        set -g mouse on
        set -g set-clipboard on
        set -g focus-events on
        set -g set-titles off
        set -g bell-action none
        set -g destroy-unattached off
        set -g renumber-windows on
        set -g prefix None
        set -g prefix2 None
        unbind-key -a -T prefix

        """
    }
}

public struct TmuxCommand: Sendable, Equatable {
    public let executable: String
    public let socketName: String
    public let configPath: String

    public init(executable: String, socketName: String, configPath: String) {
        self.executable = executable
        self.socketName = socketName
        self.configPath = configPath
    }

    public var globalArguments: [String] {
        ["-L", socketName, "-f", configPath, "-u"]
    }

    public func arguments(_ tail: [String]) -> [String] {
        globalArguments + tail
    }

    public func attachOrCreate(
        session: String,
        directory: String,
        environment: [String: String]
    ) -> [String] {
        var tail = ["set-environment", "-gr", "NO_COLOR", ";",
                    "new-session", "-A", "-D", "-s", session, "-c", directory]
        for key in environment.keys.sorted() {
            tail.append("-e")
            tail.append("\(key)=\(environment[key]!)")
        }
        return arguments(tail)
    }

    public func killSession(_ session: String) -> [String] {
        arguments(["kill-session", "-t", "=" + session])
    }

    public var listSessions: [String] {
        arguments(["list-sessions", "-F", "#{session_name}"])
    }

    public var listPanes: [String] {
        arguments(["list-panes", "-a", "-F", "#{pane_pid} #{session_name}"])
    }

    public var sourceConfiguration: [String] {
        arguments(["source-file", configPath])
    }
}
