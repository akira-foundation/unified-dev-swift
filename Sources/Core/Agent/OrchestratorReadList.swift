import Foundation

enum OrchestratorReadList {
    static let plainCommands: Set<String> = ["ls", "cat", "grep", "head", "tail", "wc", "pwd", "echo"]

    private struct Form {
        enum Positionals {
            case free
            case none
            case onlyWith(Set<String>)
        }

        var flags: Set<String> = []
        var positionals = Positionals.free
        var valuesNeedEquals: Set<String> = []
        var allowsCount = false

        func accepts(_ arguments: [String]) -> Bool {
            var named: [String] = []
            var hasPositional = false
            var flagsEnded = false
            for argument in arguments {
                guard argument.hasPrefix("-") else {
                    hasPositional = true
                    continue
                }
                guard !flagsEnded else { return false }
                if argument == "--" {
                    flagsEnded = true
                    continue
                }
                guard !valuesNeedEquals.contains(argument) else { return false }
                let name = String(argument.prefix { $0 != "=" })
                let isCount = allowsCount && argument.dropFirst().allSatisfy(\.isNumber) && argument.count > 1
                guard flags.contains(name) || isCount else { return false }
                named.append(name)
            }
            switch positionals {
            case .free: return true
            case .none: return !hasPositional
            case .onlyWith(let listing): return !hasPositional || named.contains(where: listing.contains)
            }
        }
    }

    private static let diffFlags: Set<String> = [
        "--stat", "--shortstat", "--numstat", "--name-only", "--name-status", "--patch", "-p", "--no-patch", "-s",
        "--summary", "--color", "--no-color", "--unified", "--word-diff", "--diff-filter", "--ignore-all-space", "-w",
    ]

    private static let historyFlags: Set<String> = diffFlags.union([
        "--oneline", "--format", "--pretty", "--graph", "--decorate", "--all", "--no-merges", "--merges", "--author",
        "--since", "--until", "--after", "--before", "--grep", "--reverse", "--first-parent", "-n", "--max-count",
        "--follow", "-S", "-G", "--abbrev-commit", "--date", "--branches", "--tags", "--remotes", "--left-right",
    ])

    private static let branchListing: Set<String> = [
        "--list", "-l", "--contains", "--no-contains", "--merged", "--no-merged", "--points-at",
    ]

    private static let gitForms: [String: Form] = [
        "log": Form(flags: historyFlags, allowsCount: true),
        "show": Form(flags: historyFlags, allowsCount: true),
        "diff": Form(flags: diffFlags.union(["--cached", "--staged", "--check", "--merge-base", "--quiet", "--exit-code"])),
        "status": Form(flags: ["--short", "-s", "--branch", "-b", "-sb", "--porcelain", "--long", "--untracked-files", "-u", "--ignored"]),
        "blame": Form(flags: ["-L", "-w", "-s", "-e", "--porcelain"]),
        "grep": Form(flags: ["-n", "-i", "-l", "-w", "-e", "-c", "-E", "-F", "--name-only", "--count", "--line-number", "--ignore-case", "--cached"]),
        "ls-files": Form(flags: ["--cached", "-c", "--others", "-o", "--modified", "-m", "--exclude-standard"]),
        "merge-base": Form(flags: ["--is-ancestor", "--all", "--fork-point"]),
        "rev-parse": Form(flags: [
            "--show-toplevel", "--abbrev-ref", "--short", "--verify", "--git-dir", "--git-common-dir", "--quiet", "-q",
            "--is-inside-work-tree", "--symbolic-full-name", "--show-prefix",
        ]),
        "rev-list": Form(flags: ["--count", "--left-right", "--max-count", "--all", "--first-parent", "--no-merges", "--since", "--until"]),
        "describe": Form(flags: ["--tags", "--always", "--abbrev", "--exact-match", "--long"]),
        "shortlog": Form(flags: ["-s", "-n", "-e", "-sn", "-sne", "--all", "--no-merges", "--since", "--until"]),
        "branch": Form(
            flags: branchListing.union(["--show-current", "-a", "--all", "-r", "--remotes", "-v", "-vv", "--verbose", "--format", "--sort"]),
            positionals: .onlyWith(branchListing),
            valuesNeedEquals: ["--format", "--sort"]
        ),
        "tag": Form(
            flags: branchListing.union(["--format", "--sort", "-n"]),
            positionals: .onlyWith(branchListing),
            valuesNeedEquals: ["--format", "--sort"]
        ),
        "remote": Form(flags: ["-v", "--verbose"], positionals: .none),
        "worktree list": Form(flags: ["--porcelain"], positionals: .none),
    ]

    private static let ghVerbs: [String: Set<String>] = [
        "pr": ["view", "list", "diff", "checks", "status"],
        "issue": ["view", "list", "status"],
        "run": ["view", "list", "watch"],
        "release": ["view", "list"],
        "workflow": ["view", "list"],
    ]

    private static let ghForm = Form(flags: [
        "--json", "--jq", "-q", "--template", "-t", "--comments", "-c", "--state", "-s", "--limit", "-L", "--search", "-S",
        "--label", "-l", "--author", "-A", "--assignee", "-a", "--base", "-B", "--head", "-H", "--milestone", "-m",
        "--branch", "-b", "--workflow", "--log", "--log-failed", "--exit-status", "--attempt", "--job",
        "-j", "--verbose", "-v", "--status", "--event", "-e", "--name-only", "--patch", "--color", "--required", "--watch",
        "--interval", "-i", "--draft", "-d", "--commit", "--user", "-u", "--created", "--compact",
    ])

    static func contains(_ clause: [String]) -> Bool {
        guard let head = clause.first else { return false }
        let arguments = Array(clause.dropFirst())
        if plainCommands.contains(head) { return !arguments.contains { $0.hasPrefix("--libxo") } }
        switch head {
        case "git": return gitReads(arguments)
        case "gh": return ghReads(arguments)
        default: return false
        }
    }

    private static func gitReads(_ arguments: [String]) -> Bool {
        let words = arguments.first == "--no-pager" ? Array(arguments.dropFirst()) : arguments
        guard let verb = words.first else { return false }
        if words.count > 1, let form = gitForms["\(verb) \(words[1])"] {
            return form.accepts(Array(words.dropFirst(2)))
        }
        return gitForms[verb]?.accepts(Array(words.dropFirst())) ?? false
    }

    private static func ghReads(_ arguments: [String]) -> Bool {
        guard arguments.count >= 2, ghVerbs[arguments[0]]?.contains(arguments[1]) == true,
              !arguments.contains(where: { $0.contains("://") }) else { return false }
        return ghForm.accepts(Array(arguments.dropFirst(2)))
    }
}
