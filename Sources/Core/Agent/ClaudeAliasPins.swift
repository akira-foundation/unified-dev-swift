import Foundation

enum ClaudeAliasPins {
    static func variable(for alias: String) -> String {
        "ANTHROPIC_DEFAULT_\(alias.uppercased())_MODEL"
    }

    static func pinned(_ aliases: [String], inSettingsAt url: URL) -> [String: String] {
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
