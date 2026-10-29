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
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = withoutComment(String(raw)).trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") {
                table = line.trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
                continue
            }
            guard let equals = line.firstIndex(of: "=") else { continue }
            let key = line[..<equals].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: equals)...]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            switch table.isEmpty ? key : table + "." + key {
            case credentialsStoreKey: modes.append(value == "file" ? .file : .keyring)
            case secretStorageKey: modes.append(value == "false" ? .file : .keyring)
            default: continue
            }
        }
        return modes.contains(.keyring) ? .keyring : .file
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
