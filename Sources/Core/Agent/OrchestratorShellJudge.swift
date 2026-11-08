import Foundation

enum OrchestratorShellJudge {
    static let gitVerbs = [
        "commit", "push", "pull", "merge", "rebase", "reset", "checkout", "switch", "restore", "stash",
        "cherry-pick", "revert", "am", "apply", "add", "rm", "mv", "clean",
    ]

    private static let shells: Set<String> = ["sh", "bash", "zsh", "dash", "fish"]
    private static let prefixes: Set<String> = ["env", "sudo", "command", "exec", "nohup", "time"]

    static func reads(_ command: String) -> Bool {
        let parsed = OrchestratorShellParser.parse(command)
        return parsed.isPlain && !parsed.clauses.isEmpty && parsed.clauses.allSatisfy(OrchestratorReadList.contains)
    }

    static func refuses(_ command: String) -> Bool {
        OrchestratorShellParser.parse(command).clauses.contains(where: clauseRefused)
    }

    private static func clauseRefused(_ clause: [String]) -> Bool {
        let words = Array(clause.drop { isAssignment($0) || prefixes.contains($0) })
        guard let first = words.first else { return false }
        let head = String(first.split(separator: "/").last ?? Substring(first))
        let rest = Array(words.dropFirst())
        if shells.contains(head) { return script(in: rest).map(refuses) ?? false }
        guard head == "git" else { return false }
        return gitVerb(in: rest).map(gitVerbs.contains) ?? false
    }

    static func isAssignment(_ word: String) -> Bool {
        guard let equals = word.firstIndex(of: "="), equals != word.startIndex else { return false }
        return word[..<equals].allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    private static func script(in arguments: [String]) -> String? {
        guard let flag = arguments.firstIndex(where: { $0.hasPrefix("-") && !$0.hasPrefix("--") && $0.contains("c") }),
              flag + 1 < arguments.count else { return nil }
        return arguments[flag + 1]
    }

    private static func gitVerb(in arguments: [String]) -> String? {
        var index = 0
        while index < arguments.count, arguments[index].hasPrefix("-") {
            index += arguments[index] == "-C" || arguments[index] == "-c" ? 2 : 1
        }
        return index < arguments.count ? arguments[index] : nil
    }
}
