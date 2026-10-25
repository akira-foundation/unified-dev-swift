import Foundation

public enum SpendAccounts {
    public static let unknown = "Unknown account"

    public struct Directories: Sendable {
        private struct Entry: Sendable {
            let home: AgentAccountHome
            let lexical: String
            let settled: String
        }

        private let entries: [Entry]

        public init(_ accounts: [AgentAccountHome]) {
            entries = accounts.map {
                Entry(
                    home: $0,
                    lexical: $0.directory.standardizedFileURL.path,
                    settled: TranscriptHome.settled($0.directory)
                )
            }
        }

        public func account(ofFile path: String) -> AgentAccountHome? {
            let file = URL(filePath: path)
            if let found = holder(of: file.standardizedFileURL.path) { return found }
            return holder(of: TranscriptHome.settled(file))
        }

        private func holder(of path: String) -> AgentAccountHome? {
            entries
                .filter {
                    TranscriptHome.isInside(settled: path, of: $0.lexical)
                        || TranscriptHome.isInside(settled: path, of: $0.settled)
                }
                .max { $0.settled.count < $1.settled.count }?
                .home
        }
    }

    public static func account(
        ofFile path: String,
        among accounts: [AgentAccountHome]
    ) -> AgentAccountHome? {
        Directories(accounts).account(ofFile: path)
    }

    public static func defaultHomes(
        home: URL = TranscriptHome.resolve(),
        environment: [String: String] = TranscriptHome.environment()
    ) -> [AgentAccountHome] {
        TranscriptSources.sources(home: home, environment: environment).map { source in
            let conventional = AgentAccountHome.defaultHome(for: source.provider, home: home)
            return AgentAccountHome(
                provider: source.provider,
                id: AgentAccountHome.defaultID(for: source.provider),
                directory: source.home,
                isDefault: source.home.standardizedFileURL.path
                    == conventional?.directory.standardizedFileURL.path
            )
        }
    }
}
