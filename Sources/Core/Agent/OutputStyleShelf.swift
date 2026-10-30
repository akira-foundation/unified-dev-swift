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
public final class OutputStyleShelves<Catalogue> {
    private var held: [OutputStyleShelf: Catalogue] = [:]

    public init() {}

    public func catalogue(
        project: String?,
        account: AgentAccountHome?,
        make: (AgentAccountHome?) -> Catalogue
    ) -> Catalogue {
        let shelf = OutputStyleShelf(project: project, account: account)
        if let standing = held[shelf] { return standing }
        let made = make(account)
        held[shelf] = made
        return made
    }
}
