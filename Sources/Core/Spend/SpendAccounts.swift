import Foundation

public enum SpendAccounts {
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
}
