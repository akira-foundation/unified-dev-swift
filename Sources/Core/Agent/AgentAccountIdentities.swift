import Foundation

public enum AgentAccountIdentities {
    public static func read(
        _ accounts: [AgentAccountHome],
        contents: (URL) -> Data? = { try? Data(contentsOf: $0) }
    ) -> [AgentAccountID: AgentAccountIdentity] {
        var opened: [URL: Data?] = [:]
        var identities: [AgentAccountID: AgentAccountIdentity] = [:]
        for account in accounts {
            let identity = file(account.identityPath, opened: &opened, contents: contents)
            let credential = file(account.credentialPath, opened: &opened, contents: contents)
            identities[account.id] = AgentAccountIdentity.read(
                account, identity: identity, credential: credential
            )
        }
        return identities
    }

    private static func file(
        _ path: URL,
        opened: inout [URL: Data?],
        contents: (URL) -> Data?
    ) -> Data? {
        if let seen = opened[path] { return seen }
        let data = contents(path)
        opened[path] = .some(data)
        return data
    }
}
