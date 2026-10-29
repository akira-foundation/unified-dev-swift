import Foundation

public enum AgentAccountNames {
    public static let defaultTitle = "Default account"

    public struct Entry: Sendable, Hashable {
        public let home: AgentAccountHome
        public let identity: AgentAccountIdentity?

        public init(home: AgentAccountHome, identity: AgentAccountIdentity?) {
            self.home = home
            self.identity = identity
        }
    }

    public static func title(of entry: Entry, among entries: [Entry]) -> String {
        let name = base(of: entry)
        let twins = entries.filter {
            $0.home.provider == entry.home.provider && base(of: $0) == name
        }
        guard twins.count > 1 else { return name }
        let qualifier = entry.home.isDefault ? "default" : entry.home.directory.lastPathComponent
        return "\(name) (\(qualifier))"
    }

    public static func title(
        of standing: AgentAccountStanding,
        among standings: [AgentAccountStanding]
    ) -> String {
        title(of: entry(standing), among: standings.map(entry))
    }

    public static func title(of home: AgentAccountHome, among standings: [AgentAccountStanding]) -> String? {
        standings.first { $0.home.id == home.id && $0.home.provider == home.provider }
            .map { title(of: $0, among: standings) }
    }

    public static func reference(to title: String) -> String {
        title == defaultTitle ? "the default account" : title
    }

    static func base(of entry: Entry) -> String {
        if let email = entry.identity?.email, !email.isEmpty { return email }
        return entry.home.isDefault ? defaultTitle : entry.home.directory.lastPathComponent
    }

    private static func entry(_ standing: AgentAccountStanding) -> Entry {
        Entry(home: standing.home, identity: standing.identity)
    }
}
