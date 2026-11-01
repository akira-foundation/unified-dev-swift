import Foundation

public enum OrchestratorToolGuard {
    static let editingTools: Set<String> = ["Edit", "Write", "MultiEdit", "NotebookEdit", "ApplyPatch"]

    static let shellTools: Set<String> = ["Bash", "Shell"]

    static let gitVerbs = [
        "commit", "push", "merge", "rebase", "reset", "checkout", "switch", "restore", "stash",
        "cherry-pick", "revert", "am", "apply", "add", "rm", "mv", "clean",
    ]

    static let writingCommands: Set<String> = ["rm", "mv", "cp", "mkdir", "touch", "tee", "truncate", "patch", "ln"]

    public static let claudeDisallowedTools: [String] =
        ["Edit", "Write", "MultiEdit", "NotebookEdit"] + gitVerbs.map { "Bash(git \($0):*)" }

    public static func refusal(toolName: String, input: JSONValue) -> String? {
        if editingTools.contains(toolName) {
            return refused("editing files")
        }
        guard shellTools.contains(toolName), let command = input["command"]?.stringValue else { return nil }
        return writes(command) ? refused("running a command that changes the worktree or the repository") : nil
    }

    public static let claudeArguments = [
        "--disallowedTools", claudeDisallowedTools.joined(separator: " "),
        "--append-system-prompt", OrchestratorRole.instructions,
    ]

    public static func permissionMode(_ requested: PermissionMode, orchestrates: Bool) -> PermissionMode {
        orchestrates ? permissionMode(requested) : requested
    }

    public static func permissionMode(_ requested: PermissionMode) -> PermissionMode {
        switch requested {
        case .bypassPermissions, .acceptEdits, .autoReview: .auto
        case .auto, .plan: requested
        }
    }

    public static func prompt(_ text: String, orchestrates: Bool, opensSession: Bool) -> String {
        guard orchestrates, opensSession else { return text }
        return OrchestratorRole.instructions + "\n\n" + text
    }

    static func writes(_ command: String) -> Bool {
        if redirectsIntoAFile(command) { return true }
        for clause in clauses(of: command) {
            let words = clause.split(whereSeparator: \.isWhitespace).map(String.init)
            guard let head = words.first else { continue }
            if writingCommands.contains(head) { return true }
            if head == "sed", words.contains(where: { $0.hasPrefix("-i") }) { return true }
            if head == "git", let verb = gitVerb(in: words), gitVerbs.contains(verb) { return true }
        }
        return false
    }

    private static func clauses(of command: String) -> [Substring] {
        command.split { "|;&\n".contains($0) }
    }

    private static func gitVerb(in words: [String]) -> String? {
        var index = 1
        while index < words.count {
            let word = words[index]
            if word == "-C" || word == "-c" {
                index += 2
                continue
            }
            if word.hasPrefix("-") {
                index += 1
                continue
            }
            return word
        }
        return nil
    }

    private static func redirectsIntoAFile(_ command: String) -> Bool {
        var rest = Substring(command)
        while let arrow = rest.firstIndex(of: ">") {
            rest = rest[rest.index(after: arrow)...]
            if rest.first == ">" { rest = rest.dropFirst() }
            let target = rest.drop { $0 == " " }
            if !target.hasPrefix("&"), !target.hasPrefix("/dev/null") { return true }
        }
        return false
    }

    private static func refused(_ what: String) -> String {
        "This workspace is the project's orchestrator, and Unified Dev refuses \(what) here. "
            + "Start a workspace with workspace_start for the change and follow it from here."
    }
}
