import Foundation

public struct OutputStyleShelf: Hashable, Sendable {
    public let project: String
    public let account: AgentAccountID?

    public init(project: String?, account: AgentAccountHome?) {
        self.project = project ?? ""
        self.account = account?.id
    }
}
