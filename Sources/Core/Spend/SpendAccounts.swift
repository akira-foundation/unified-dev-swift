import Foundation

public enum SpendAccounts {
    public static func accountID(
        ofFile path: String,
        among accounts: [AgentAccountHome]
    ) -> AgentAccountID? {
        let file = URL(filePath: path)
        return accounts
            .filter { TranscriptHome.isInside(file, of: $0.directory) }
            .max { TranscriptHome.settled($0.directory).count < TranscriptHome.settled($1.directory).count }?
            .id
    }
}
