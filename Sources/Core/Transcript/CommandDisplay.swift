import Foundation

public struct CommandDisplay: Equatable, Sendable {
    public enum Place: Equatable, Sendable {
        case workspace
        case subdirectory(String)
        case elsewhere(prefix: String)
        case unstated
    }

    public enum Lead: Equatable, Sendable {
        case none
        case location(String)
        case prefix(String)

        public var text: String {
            switch self {
            case .none: ""
            case .location(let path): path
            case .prefix(let text): text
            }
        }

        public var joiner: String {
            switch self {
            case .none: ""
            case .location: " \u{203A} "
            case .prefix: " "
            }
        }

        public var tint: ToolTint {
            switch self {
            case .none: .neutral
            case .location: .accent
            case .prefix: .warning
            }
        }
    }

    public var place: Place
    public var command: String

    public init(place: Place, command: String) {
        self.place = place
        self.command = command
    }

    public var lead: Lead {
        switch place {
        case .workspace, .unstated: .none
        case .subdirectory(let path): .location(path)
        case .elsewhere(let prefix): prefix.isEmpty ? .none : .prefix(prefix)
        }
    }

    public var leftTheWorkspace: Bool {
        if case .elsewhere = place { return true }
        return false
    }

    public var line: String {
        let lead = lead
        return lead.text.isEmpty ? command : lead.text + lead.joiner + command
    }

    public static func of(_ command: String, worktree: String) -> CommandDisplay {
        let untouched = CommandDisplay(place: .unstated, command: command)
        guard worktree.hasPrefix("/") else { return untouched }
        let root = normalise(worktree)
        guard root != "/" else { return untouched }

        var rest = Substring(command)
        var directory = root
        var moved = false

        loop: while true {
            switch step(rest, from: directory) {
            case .notMoved:
                break loop
            case .opaque:
                return CommandDisplay(place: .elsewhere(prefix: ""), command: command)
            case .moved(let destination, let remainder):
                directory = destination
                rest = remainder
                moved = true
            }
        }

        guard moved else { return untouched }

        guard let below = relation(of: directory, to: root) else {
            guard !rest.isEmpty else {
                return CommandDisplay(place: .elsewhere(prefix: ""), command: command)
            }
            let consumed = ToolPresenter.oneLine(String(command[..<rest.startIndex]))
            return CommandDisplay(place: .elsewhere(prefix: consumed), command: String(rest))
        }
        guard !rest.isEmpty else { return untouched }
        return CommandDisplay(
            place: below.isEmpty ? .workspace : .subdirectory(below),
            command: String(rest)
        )
    }

    private enum Step {
        case notMoved
        case opaque
        case moved(String, Substring)
    }

    private static func step(_ text: Substring, from directory: String) -> Step {
        var scan = text.drop(while: \.isWhitespace)
        guard scan.hasPrefix("cd") else { return .notMoved }
        scan = scan.dropFirst(2)
        guard let next = scan.first, next == " " || next == "\t" else { return .notMoved }
        scan = scan.drop(while: { $0 == " " || $0 == "\t" })

        guard let word = word(&scan) else { return .opaque }
        let readable = !word.contains("$") && !word.contains("`") && !word.hasPrefix("~") && word != "-"
        guard readable else { return .opaque }

        var after = scan.drop(while: { $0 == " " || $0 == "\t" })
        if after.hasPrefix("&&") {
            after = after.dropFirst(2)
        } else if after.hasPrefix(";") {
            after = after.dropFirst()
        } else if let first = after.first, !first.isNewline {
            return .notMoved
        }

        return .moved(resolve(word, against: directory), after.drop(while: \.isWhitespace))
    }

    private static func word(_ scan: inout Substring) -> String? {
        var out = ""
        var quote: Character?

        while let character = scan.first {
            if let open = quote {
                scan = scan.dropFirst()
                if character == open { quote = nil } else { out.append(character) }
                continue
            }
            if character == "'" || character == "\"" {
                quote = character
                scan = scan.dropFirst()
                continue
            }
            if character == "\\" {
                scan = scan.dropFirst()
                guard let escaped = scan.first else { return nil }
                out.append(escaped)
                scan = scan.dropFirst()
                continue
            }
            if character.isWhitespace || character == ";" || character == "&" || character == "|" { break }
            out.append(character)
            scan = scan.dropFirst()
        }

        guard quote == nil, !out.isEmpty else { return nil }
        return out
    }

    private static func resolve(_ path: String, against directory: String) -> String {
        path.hasPrefix("/") ? normalise(path) : normalise(directory + "/" + path)
    }

    private static func normalise(_ path: String) -> String {
        var components: [Substring] = []
        for part in path.split(separator: "/") {
            if part == "." { continue }
            if part == ".." { _ = components.popLast(); continue }
            components.append(part)
        }
        return "/" + components.joined(separator: "/")
    }

    private static func relation(of path: String, to root: String) -> String? {
        if path == root { return "" }
        guard path.hasPrefix(root + "/") else { return nil }
        return String(path.dropFirst(root.count + 1))
    }
}
