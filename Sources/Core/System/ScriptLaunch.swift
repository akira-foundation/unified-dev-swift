import Foundation

public enum ScriptLaunch: Sendable, Hashable {
    case executable(path: String)
    case source(String)
    case missing(path: String)

    public static func resolve(
        text: String?, file: ScriptFile?, repo: String,
        manager: FileManager = .default
    ) -> ScriptLaunch? {
        if let file {
            let full = SettingsLoader.resolve(file.path, repo: repo)
            guard !file.isMissing, manager.fileExists(atPath: full) else {
                return .missing(path: file.path)
            }
            if manager.isExecutableFile(atPath: full), hasShebang(text ?? "") {
                return .executable(path: full)
            }
            guard let text, !text.trimmed.isEmpty else { return nil }
            return .source(text)
        }

        guard let text, !text.trimmed.isEmpty else { return nil }
        return .source(text)
    }

    static func hasShebang(_ text: String) -> Bool {
        text.hasPrefix("#!")
    }

    public var executable: String {
        switch self {
        case .executable(let path): path
        case .source, .missing: "/bin/zsh"
        }
    }

    public var arguments: [String] {
        switch self {
        case .executable: []
        case .source(let text): ["-c", text]
        case .missing: ["-c", "true"]
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
