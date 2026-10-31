import Foundation

public enum SpendAccounts {
    public static let unknown = "Unknown account"

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
