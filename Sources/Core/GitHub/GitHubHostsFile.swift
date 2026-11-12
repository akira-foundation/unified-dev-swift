import Foundation

enum GitHubHostsFile {
    static func holdsToken(in directory: URL) -> Bool {
        guard let contents = try? String(
            contentsOf: directory.appending(path: "hosts.yml"), encoding: .utf8
        ) else { return false }
        return contents.split(whereSeparator: \.isNewline).contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("oauth_token:") else { return false }
            let value = trimmed.dropFirst("oauth_token:".count).trimmingCharacters(in: .whitespaces)
            return !value.isEmpty && value != "\"\"" && value != "''"
        }
    }
}
