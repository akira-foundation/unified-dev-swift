import Foundation

public enum AgentAccountOrphans {
    public struct Candidate: Sendable, Hashable {
        public let provider: AgentKind
        public let name: String
        public let directory: URL

        public init(provider: AgentKind, name: String, directory: URL) {
            self.provider = provider
            self.name = name
            self.directory = directory
        }
    }

    public static func orphans(
        among candidates: [Candidate],
        rows: [AgentAccountRow],
        defaults: [AgentAccountHome],
        excluding busy: [URL] = []
    ) -> [AgentAccountHome] {
        let defaultDirectories = Set(defaults.map { TranscriptHome.settled($0.directory) })
        let busyDirectories = Set(busy.map(TranscriptHome.settled))
        return candidates
            .filter { candidate in
                let settled = TranscriptHome.settled(candidate.directory)
                return !rows.contains { $0.provider == candidate.provider && $0.id.rawValue == candidate.name }
                    && !defaultDirectories.contains(settled)
                    && !busyDirectories.contains(settled)
            }
            .map {
                AgentAccountHome(
                    provider: $0.provider, id: AgentAccountID($0.name), directory: $0.directory, isDefault: false
                )
            }
    }

    public static func find(
        support: URL,
        rows: [AgentAccountRow],
        defaults: [AgentAccountHome],
        excluding busy: [URL] = []
    ) -> [AgentAccountHome] {
        let root = AgentAccountHomes.root(support: support)
        let candidates = AgentKind.allCases.flatMap { provider -> [Candidate] in
            let folder = root.appending(path: provider.rawValue, directoryHint: .isDirectory)
            let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
            return names.sorted().compactMap { name -> Candidate? in
                let directory = folder.appending(path: name, directoryHint: .isDirectory)
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
                      isDirectory.boolValue
                else { return nil }
                return Candidate(provider: provider, name: name, directory: directory)
            }
        }
        return orphans(among: candidates, rows: rows, defaults: defaults, excluding: busy)
    }
}
