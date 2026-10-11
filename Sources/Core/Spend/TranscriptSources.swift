import Foundation

public struct TranscriptSource: Sendable, Hashable {
    public var provider: AgentKind
    public var root: URL
    public var namePrefix: String

    public init(provider: AgentKind, root: URL, namePrefix: String = "") {
        self.provider = provider
        self.root = root
        self.namePrefix = namePrefix
    }
}

public struct TranscriptFile: Sendable, Hashable, Identifiable {
    public var provider: AgentKind
    public var url: URL
    public var size: Int
    public var modifiedAt: Date

    public var id: String { url.path }

    public init(provider: AgentKind, url: URL, size: Int, modifiedAt: Date) {
        self.provider = provider
        self.url = url
        self.size = size
        self.modifiedAt = modifiedAt
    }

    public var agentSessionID: String {
        let stem = url.deletingPathExtension().lastPathComponent
        guard stem.hasPrefix("rollout-") else { return stem }
        let parts = stem.split(separator: "-")
        guard parts.count >= 5 else { return stem }
        return parts.suffix(5).joined(separator: "-")
    }
}

public enum TranscriptSources {
    public static let extensionName = "jsonl"

    public static func sources(
        home: URL,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> [TranscriptSource] {
        [
            TranscriptSource(
                provider: .claudeCode,
                root: claudeHome(home: home, environment: environment).appending(path: "projects")
            ),
            TranscriptSource(
                provider: .codex,
                root: codexHome(home: home, environment: environment).appending(path: "sessions"),
                namePrefix: "rollout-"
            ),
        ]
    }

    static func claudeHome(home: URL, environment: [String: String]) -> URL {
        directory(named: "CLAUDE_CONFIG_DIR", in: environment) ?? home.appending(path: ".claude")
    }

    static func codexHome(home: URL, environment: [String: String]) -> URL {
        directory(named: "CODEX_HOME", in: environment) ?? home.appending(path: ".codex")
    }

    private static func directory(named name: String, in environment: [String: String]) -> URL? {
        guard let value = environment[name], !value.isEmpty else { return nil }
        return URL(filePath: value)
    }

    public static func files(
        in source: TranscriptSource,
        manager: FileManager = .default
    ) -> [TranscriptFile] {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]
        guard let walker = manager.enumerator(
            at: source.root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var found: [TranscriptFile] = []
        for case let url as URL in walker {
            guard url.pathExtension == extensionName,
                  source.namePrefix.isEmpty || url.lastPathComponent.hasPrefix(source.namePrefix),
                  let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  let size = values.fileSize,
                  let modifiedAt = values.contentModificationDate
            else { continue }
            found.append(TranscriptFile(
                provider: source.provider, url: url, size: size, modifiedAt: modifiedAt
            ))
        }
        return found.sorted { $0.modifiedAt > $1.modifiedAt }
    }
}
