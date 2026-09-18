import Foundation

public enum WorkspaceStartingPoint: Sendable, Hashable, Codable {
    case newBranch(from: String)
    case existingBranch(ExistingBranch)
    case pullRequest(PullRequestListing)

    public init?(_ source: WorkspaceSource) {
        switch source {
        case .newBranch(let base): self = .newBranch(from: base)
        case .existingBranch(let branch): self = .existingBranch(branch)
        case .pullRequest(.listed(let request)): self = .pullRequest(request)
        case .pullRequest(.typed): return nil
        }
    }

    public init(_ checkout: WorkspaceCheckout) {
        switch checkout {
        case .branch(let branch): self = .existingBranch(branch)
        case .pullRequest(let request): self = .pullRequest(request)
        }
    }

    public var source: WorkspaceSource {
        switch self {
        case .newBranch(let base): .newBranch(from: base)
        case .existingBranch(let branch): .existingBranch(branch)
        case .pullRequest(let request): .pullRequest(.listed(request))
        }
    }

    public var checkout: WorkspaceCheckout? { source.checkout }

    public var baseBranch: String? {
        guard case .newBranch(let base) = self else { return nil }
        return base
    }
}

public struct WorkspaceDraftControls: Sendable, Hashable, Codable {
    public var model: String
    public var effort: String
    public var agentKind: AgentKind
    public var permissionMode: PermissionMode
    public var interactionMode: InteractionMode
    public var usesCLIChat: Bool

    public init(_ controls: ComposerControls, usesCLIChat: Bool) {
        model = controls.model
        effort = controls.effort
        agentKind = controls.agentKind
        permissionMode = controls.permissionMode
        interactionMode = controls.interactionMode
        self.usesCLIChat = usesCLIChat
    }

    public func applied(to controls: ComposerControls) -> ComposerControls {
        var applied = controls
        applied.agentKind = agentKind
        applied.model = model
        applied.effort = effort
        applied.permissionMode = permissionMode
        applied.interactionMode = interactionMode
        return applied
    }
}

public struct WorkspaceDraft: Sendable, Hashable {
    public var repoID: RepoID
    public var startingPoint: WorkspaceStartingPoint
    public var prompt: String
    public var controls: WorkspaceDraftControls?
    public var attachmentKey: String
    public var updatedAt: Date

    public init(
        repoID: RepoID,
        startingPoint: WorkspaceStartingPoint,
        prompt: String = "",
        controls: WorkspaceDraftControls? = nil,
        attachmentKey: String = PromptAttachments.newShortID(),
        updatedAt: Date = Date()
    ) {
        self.repoID = repoID
        self.startingPoint = startingPoint
        self.prompt = prompt
        self.controls = controls
        self.attachmentKey = attachmentKey
        self.updatedAt = updatedAt
    }

    public var hasContent: Bool { prompt.contains { !$0.isWhitespace } }

    public func holdsWork(attachmentCount: Int) -> Bool { hasContent || attachmentCount > 0 }

    public static func isStagingKey(_ key: String) -> Bool {
        !key.isEmpty && key.count <= 64
            && key.unicodeScalars.allSatisfy { $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_") }
    }

    public static func receiving(_ text: String, into prompt: String) -> String {
        let incoming = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !incoming.isEmpty else { return prompt }
        guard prompt.contains(where: { !$0.isWhitespace }) else { return incoming }
        return prompt.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n" + incoming
    }
}
