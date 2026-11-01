import Foundation

enum OrchestratorShellJudge {
    static let gitVerbs = [
        "commit", "push", "pull", "merge", "rebase", "reset", "checkout", "switch", "restore", "stash",
        "cherry-pick", "revert", "am", "apply", "add", "rm", "mv", "clean",
    ]

    static let writingCommands: Set<String> = [
        "rm", "rmdir", "unlink", "mv", "cp", "mkdir", "touch", "tee", "truncate", "patch", "ln", "chmod", "chown",
    ]

    private static let shells: Set<String> = ["sh", "bash", "zsh", "dash", "fish"]
    private static let prefixes: Set<String> = ["env", "sudo", "command", "exec", "nohup", "time"]
    private static let harmlessTargets: Set<String> = ["/dev/null", "/dev/stdout", "/dev/stderr"]

    struct Parsed: Equatable {
        var clauses: [[String]] = []
        var redirectsIntoAFile = false
    }

    static func writes(_ command: String) -> Bool {
        let parsed = parse(command)
        if parsed.redirectsIntoAFile { return true }
        return parsed.clauses.contains { clauseWrites($0) }
    }

    static func parse(_ command: String) -> Parsed {
        var parsed = Parsed()
        var clause: [String] = []
        var word = ""
        var quote: Character?
        var hasWord = false
        var awaitingTarget = false
        var characters = Array(command)[...]

        func endWord() {
            guard hasWord else { return }
            if awaitingTarget {
                if !harmlessTargets.contains(word) { parsed.redirectsIntoAFile = true }
                awaitingTarget = false
            } else {
                clause.append(word)
            }
            word = ""
            hasWord = false
        }

        func endClause() {
            endWord()
            if !clause.isEmpty { parsed.clauses.append(clause) }
            clause = []
        }

        while let character = characters.popFirst() {
            if let open = quote {
                if character == open {
                    quote = nil
                } else {
                    word.append(character)
                }
                continue
            }
            switch character {
            case "'", "\"":
                quote = character
                hasWord = true
            case "\\":
                if let next = characters.popFirst() { word.append(next) }
                hasWord = true
            case ">":
                if hasWord, word.allSatisfy(\.isNumber) {
                    word = ""
                    hasWord = false
                }
                endWord()
                if characters.first == ">" { characters = characters.dropFirst() }
                if characters.first == "&" {
                    characters = characters.dropFirst().drop { $0.isNumber || $0 == "-" }
                } else {
                    awaitingTarget = true
                }
            case "|", ";", "&", "\n", "(", ")", "{", "}", "`":
                endClause()
            default:
                if character.isWhitespace {
                    endWord()
                } else {
                    word.append(character)
                    hasWord = true
                }
            }
        }
        endClause()
        if awaitingTarget { parsed.redirectsIntoAFile = true }
        return parsed
    }

    private static func clauseWrites(_ clause: [String]) -> Bool {
        let words = Array(clause.drop { isAssignment($0) || prefixes.contains($0) })
        guard let first = words.first else { return false }
        let head = String(first.split(separator: "/").last ?? Substring(first))
        let rest = Array(words.dropFirst())
        if shells.contains(head) {
            return script(in: rest).map(writes) ?? false
        }
        if writingCommands.contains(head) { return true }
        if head == "sed" { return rest.contains { $0.hasPrefix("-i") || $0.hasPrefix("--in-place") } }
        if head == "perl" { return rest.contains(where: isPerlInPlaceFlag) }
        if head == "git" { return gitWrites(rest) }
        return false
    }

    private static func isPerlInPlaceFlag(_ word: String) -> Bool {
        guard word.hasPrefix("-"), !word.hasPrefix("--"), !word.hasPrefix("-M"), !word.hasPrefix("-I") else { return false }
        return word.dropFirst().prefix { $0.isLetter }.contains("i")
    }

    private static func isAssignment(_ word: String) -> Bool {
        guard let equals = word.firstIndex(of: "="), equals != word.startIndex else { return false }
        return word[..<equals].allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    private static func script(in arguments: [String]) -> String? {
        guard let flag = arguments.firstIndex(where: { $0.hasPrefix("-") && !$0.hasPrefix("--") && $0.contains("c") }),
              flag + 1 < arguments.count else { return nil }
        return arguments[flag + 1]
    }

    private static func isTagListing(_ word: String) -> Bool {
        let listing = ["-l", "--list", "--contains", "--no-contains", "--merged", "--no-merged", "--points-at", "--sort"]
        return listing.contains { word == $0 || word.hasPrefix($0 + "=") }
    }

    private static func gitWrites(_ arguments: [String]) -> Bool {
        var index = 0
        while index < arguments.count, arguments[index].hasPrefix("-") {
            index += arguments[index] == "-C" || arguments[index] == "-c" ? 2 : 1
        }
        guard index < arguments.count else { return false }
        let verb = arguments[index]
        let rest = Array(arguments.dropFirst(index + 1))
        switch verb {
        case "stash": return !["list", "show"].contains(rest.first ?? "push")
        case "apply": return !rest.contains { ["--check", "--stat", "--numstat", "--summary"].contains($0) }
        case "branch": return rest.contains { ["-d", "-D", "-m", "-M", "-c", "-C", "-f", "--delete", "--move", "--copy", "--force"].contains($0) }
        case "tag": return rest.contains("-d") || rest.contains("--delete")
            || (!rest.contains(where: isTagListing) && rest.contains { !$0.hasPrefix("-") })
        case "worktree": return ["add", "remove", "move", "prune"].contains(rest.first ?? "")
        default: return gitVerbs.contains(verb)
        }
    }
}
