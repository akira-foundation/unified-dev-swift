import Foundation

public enum ClaudeAliasPins {
    static func variable(for alias: String) -> String {
        "ANTHROPIC_DEFAULT_\(alias.uppercased())_MODEL"
    }

    static func settingsFile(of account: AgentAccountHome?) -> URL {
        accountDirectory(account).appending(path: "settings.json")
    }

    static func accountDirectory(_ account: AgentAccountHome?) -> URL {
        account?.directory
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude", directoryHint: .isDirectory)
    }

    public static func pinned(_ aliases: [String], inSettingsAt url: URL) -> [String: String] {
        guard let data = FileManager.default.contents(atPath: url.path),
              let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let env = settings["env"] as? [String: Any] else { return [:] }
        var pins: [String: String] = [:]
        for alias in aliases {
            guard let value = env[variable(for: alias)] as? String else { continue }
            let model = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !model.isEmpty { pins[alias] = model }
        }
        return pins
    }
}
