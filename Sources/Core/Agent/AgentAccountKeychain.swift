import Foundation

public struct AgentAccountKeychain: Sendable {
    public struct Entry: Sendable, Hashable {
        public let service: String
        public let account: String

        public init(service: String, account: String) {
            self.service = service
            self.account = account
        }
    }

    static let securityTool = "/usr/bin/security"
    static let entryNotFound: Int32 = 44

    private let deleteEntry: @Sendable (Entry) async -> Bool

    public init(delete: @escaping @Sendable (Entry) async -> Bool) {
        deleteEntry = delete
    }

    func delete(_ entry: Entry) async -> Bool {
        await deleteEntry(entry)
    }

    static func deletionArguments(for entry: Entry) -> [String] {
        ["delete-generic-password", "-a", entry.account, "-s", entry.service]
    }

    static func isGone(exitStatus: Int32) -> Bool {
        exitStatus == 0 || exitStatus == entryNotFound
    }

    static func running(
        _ run: @escaping @Sendable (String, [String]) async throws -> Int32
    ) -> AgentAccountKeychain {
        AgentAccountKeychain { entry in
            guard let status = try? await run(securityTool, deletionArguments(for: entry)) else { return false }
            return isGone(exitStatus: status)
        }
    }

    public static let login = running { tool, arguments in
        try await Shell.run(tool, arguments, timeout: .seconds(30)).status
    }

    public static let untouched = AgentAccountKeychain { _ in true }
}
