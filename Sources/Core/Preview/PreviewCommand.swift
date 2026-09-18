import Foundation

public enum PreviewCommand {
    public struct Result: Sendable, Equatable {
        public var status: Int32
        public var output: String
        public var error: String
    }

    public static let usage = """
        usage: preview identity --worktree <path> [--branch <name>] [--label <text>]
               preview check <scenario.json>
        """

    public static func run(_ arguments: [String]) -> Result {
        guard let command = arguments.first else { return failure(usage) }
        let rest = Array(arguments.dropFirst())
        switch command {
        case "identity": return identity(rest)
        case "check": return check(rest)
        default: return failure(usage)
        }
    }

    static func identity(_ arguments: [String]) -> Result {
        var options: [String: String] = [:]
        var index = 0
        while index < arguments.count {
            let flag = arguments[index]
            guard ["--worktree", "--branch", "--label"].contains(flag), index + 1 < arguments.count else {
                return failure(usage)
            }
            options[flag] = arguments[index + 1]
            index += 2
        }
        guard let worktree = options["--worktree"] else { return failure(usage) }
        do {
            let identity = try PreviewIdentity(
                worktree: worktree, branch: options["--branch"], label: options["--label"]
            )
            let lines = identity.fields.map { "\($0.key)=\($0.value)" }
            return Result(status: 0, output: lines.joined(separator: "\n") + "\n", error: "")
        } catch {
            return failure(String(describing: error))
        }
    }

    static func check(_ arguments: [String]) -> Result {
        guard arguments.count == 1 else { return failure(usage) }
        do {
            let scenario = try PreviewScenario.read(path: arguments[0])
            let workspaces = scenario.projects.reduce(0) { $0 + $1.workspaces.count }
            let chats = scenario.projects.flatMap(\.workspaces).reduce(0) { $0 + $1.chats.count }
            return Result(
                status: 0,
                output: "\(scenario.projects.count) projects, \(workspaces) workspaces, \(chats) chats\n",
                error: ""
            )
        } catch {
            return failure(String(describing: error))
        }
    }

    private static func failure(_ message: String) -> Result {
        Result(status: 1, output: "", error: message + "\n")
    }
}
