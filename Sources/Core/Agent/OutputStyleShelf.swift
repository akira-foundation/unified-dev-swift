import Foundation

public struct OutputStyleShelf: Hashable, Sendable {
    public let project: String
    public let account: AgentAccountID?

    public init(project: String?, account: AgentAccountHome?) {
        self.project = project ?? ""
        self.account = account?.id
    }
}

@MainActor
public protocol AccountBound {
    init(account: AgentAccountHome?)
}

@MainActor
public final class OutputStyleShelves<Catalogue: AccountBound> {
    private var held: [OutputStyleShelf: Catalogue] = [:]

    public init() {}

    public func catalogue(project: String?, account: AgentAccountHome?) -> Catalogue {
        let shelf = OutputStyleShelf(project: project, account: account)
        if let standing = held[shelf] { return standing }
        let made = Catalogue(account: account)
        held[shelf] = made
        return made
    }
}
