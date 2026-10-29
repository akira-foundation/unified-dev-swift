import Foundation

public enum CodexAuthStorageMode: Sendable, Hashable {
    case file
    case keyring

    static let credentialsStoreKey = "cli_auth_credentials_store"
    static let secretStorageKey = "features.secret_auth_storage"

    public static func read(configTOML: Data?) -> CodexAuthStorageMode {
        guard let configTOML, let text = String(data: configTOML, encoding: .utf8) else { return .file }
        var table = ""
        var modes: [CodexAuthStorageMode] = []
        var hasUnreadMention = false
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = withoutComment(String(raw)).trimmingCharacters(in: .whitespaces)
            let mentionsKey = mentionedKeys.contains { line.contains($0) }
            if line.hasPrefix("[") {
                table = line.trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
                hasUnreadMention = hasUnreadMention || mentionsKey
                continue
            }
            guard let equals = line.firstIndex(of: "=") else {
                hasUnreadMention = hasUnreadMention || mentionsKey
                continue
            }
            let key = unquoted(line[..<equals])
            let value = unquoted(line[line.index(after: equals)...])
            switch table.isEmpty ? key : table + "." + key {
            case credentialsStoreKey: modes.append(value == "file" ? .file : .keyring)
            case secretStorageKey: modes.append(value == "false" ? .file : .keyring)
            default: hasUnreadMention = hasUnreadMention || (mentionsKey && !namesKey(key))
            }
        }
        return modes.contains(.keyring) || hasUnreadMention ? .keyring : .file
    }

    private static let mentionedKeys = [credentialsStoreKey, "secret_auth_storage"]

    private static func namesKey(_ key: String) -> Bool {
        key == credentialsStoreKey || key.hasSuffix("secret_auth_storage")
    }

    private static func unquoted(_ text: Substring) -> String {
        text.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }

    private static func withoutComment(_ line: String) -> String {
        var quote: Character?
        for index in line.indices {
            let character = line[index]
            switch (quote, character) {
            case (let open?, _) where character == open: quote = nil
            case (nil, "\""), (nil, "'"): quote = character
            case (nil, "#"): return String(line[..<index])
            default: continue
            }
        }
        return line
    }
}
