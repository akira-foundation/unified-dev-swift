import Foundation

public enum SpendAccounts {
    public static let unknown = "Unknown account"

    public static func accountID(
        ofFile path: String,
        among accounts: [AgentAccountHome]
    ) -> AgentAccountID? {
        let file = TranscriptHome.settled(URL(filePath: path))
        return accounts
            .map { (id: $0.id, directory: TranscriptHome.settled($0.directory)) }
            .filter { TranscriptHome.isInside(settled: file, of: $0.directory) }
            .max { $0.directory.count < $1.directory.count }?
            .id
    }

    public static func defaultHomes(
        home: URL = TranscriptHome.resolve(),
        environment: [String: String] = TranscriptHome.environment()
    ) -> [AgentAccountHome] {
        TranscriptSources.sources(home: home, environment: environment).map {
            AgentAccountHome(
                provider: $0.provider,
                id: AgentAccountHome.defaultID(for: $0.provider),
                directory: $0.home,
                isDefault: true
            )
        }
    }
}
