import Foundation

public struct SpendAccountAttribution: Sendable {
    private struct Settled: Sendable {
        let id: AgentAccountID
        let directory: String
    }

    private let accounts: [Settled]

    public init(accounts: [AgentAccountHome]) {
        self.accounts = accounts.map { Settled(id: $0.id, directory: TranscriptHome.settled($0.directory)) }
    }

    public func accountID(ofFile path: String) -> AgentAccountID? {
        let file = TranscriptHome.settled(URL(filePath: path))
        return accounts
            .filter { TranscriptHome.isInside(settled: file, of: $0.directory) }
            .max { $0.directory.count < $1.directory.count }?
            .id
    }
}
