import Foundation

public enum AgentAccountNames {
    public static let defaultTitle = "Default account"

    public static func title(
        of standing: AgentAccountStanding,
        among standings: [AgentAccountStanding]
    ) -> String {
        let name = base(of: standing)
        let twins = standings.filter {
            $0.home.provider == standing.home.provider && base(of: $0) == name
        }
        guard twins.count > 1 else { return name }
        let qualifier = standing.home.isDefault ? "default" : standing.home.directory.lastPathComponent
        return "\(name) (\(qualifier))"
    }

    public static func title(of home: AgentAccountHome, among standings: [AgentAccountStanding]) -> String? {
        standings.first { $0.home.id == home.id && $0.home.provider == home.provider }
            .map { title(of: $0, among: standings) }
    }

    static func base(of standing: AgentAccountStanding) -> String {
        if let email = standing.identity.email, !email.isEmpty { return email }
        return standing.home.isDefault ? defaultTitle : standing.home.directory.lastPathComponent
    }
}
