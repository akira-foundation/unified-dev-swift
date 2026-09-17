import Foundation

public enum WorkspaceBrowserURL {
    public static let file = "\(WorktreeScratch.generated)/url"

    public static func path(inWorktree worktree: String) -> String {
        (worktree as NSString).appendingPathComponent(file)
    }

    public static func resolve(
        written: String?, stated: String?, environment: [String: String], port: Int
    ) -> String {
        if let address = address(written) { return address }
        if let address = address(stated.map { expand($0, with: environment) }) { return address }
        return port > 0 ? "http://localhost:\(port)" : ""
    }

    public static func read(
        worktree: String, settings: RepoSettings, environment: [String: String], port: Int
    ) -> String {
        let written = try? String(contentsOfFile: path(inWorktree: worktree), encoding: .utf8)
        return resolve(
            written: written, stated: settings.browserURL, environment: environment, port: port
        )
    }

    static func address(_ raw: String?) -> String? {
        guard let line = raw?
            .components(separatedBy: .newlines)
            .lazy
            .map({ $0.trimmingCharacters(in: .whitespaces) })
            .first(where: { !$0.isEmpty })
        else { return nil }
        return line.contains("://") ? line : "http://" + line
    }

    static func expand(_ template: String, with environment: [String: String]) -> String {
        var result = ""
        var rest = Substring(template)

        while let dollar = rest.firstIndex(of: "$") {
            result += rest[rest.startIndex..<dollar]

            var cursor = rest.index(after: dollar)
            let braced = cursor < rest.endIndex && rest[cursor] == "{"
            if braced { cursor = rest.index(after: cursor) }

            var name = ""
            while cursor < rest.endIndex, isNameCharacter(rest[cursor]) {
                name.append(rest[cursor])
                cursor = rest.index(after: cursor)
            }

            let closed = !braced || (cursor < rest.endIndex && rest[cursor] == "}")
            if braced, closed { cursor = rest.index(after: cursor) }

            if !name.isEmpty, closed, let value = environment[name] {
                result += value
            } else {
                result += rest[dollar..<cursor]
            }
            rest = rest[cursor...]
        }

        return result + rest
    }

    private static func isNameCharacter(_ character: Character) -> Bool {
        character == "_" || (character.isASCII && (character.isLetter || character.isNumber))
    }
}
