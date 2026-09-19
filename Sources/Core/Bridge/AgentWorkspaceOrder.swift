import CryptoKit
import Foundation

public struct AgentWorkspaceOrder: Sendable, Hashable {
    public let prompt: String
    public let name: String?
    public let source: AgentStartSource
    public let agent: AgentKind?
    public let model: String?

    public var baseBranch: String? { source.baseBranch }

    public init(
        prompt: String,
        name: String? = nil,
        source: AgentStartSource = .newBranch(from: nil),
        agent: AgentKind? = nil,
        model: String? = nil
    ) {
        self.prompt = prompt
        self.name = name
        self.source = source
        self.agent = agent
        self.model = model
    }
}

public struct StartedWorkspaceSummary: Sendable, Hashable {
    public let workspaceID: WorkspaceID
    public let name: String
    public let branch: String
    public let path: String

    public init(workspaceID: WorkspaceID, name: String, branch: String, path: String) {
        self.workspaceID = workspaceID
        self.name = name
        self.branch = branch
        self.path = path
    }
}

extension AgentWorkspaceOrder {
    func spawnID(parentWorkspaceID: WorkspaceID, otherProject: RepoID? = nil) -> String {
        guard let otherProject else { return spawnID(scope: parentWorkspaceID.rawValue) }
        return spawnID(scope: parentWorkspaceID.rawValue + "\u{0}project\u{0}" + otherProject.rawValue)
    }

    func spawnID(suggestion: WorkSuggestionID) -> String {
        spawnID(scope: "suggestion\u{0}" + suggestion.rawValue)
    }

    func spawnID(ownerProject: RepoID) -> String {
        spawnID(scope: "owner\u{0}" + ownerProject.rawValue)
    }

    private func spawnID(scope: String) -> String {
        var parts = [
            scope,
            prompt,
            name ?? "",
        ] + source.digestMaterial + [
            agent?.rawValue ?? "",
        ]
        if let model { parts.append(model) }
        let material = parts.joined(separator: "\u{0}")

        let digest = SHA256.hash(data: Data(material.utf8))

        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}
