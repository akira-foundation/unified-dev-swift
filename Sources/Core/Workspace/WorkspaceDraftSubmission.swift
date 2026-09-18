import Foundation

public struct WorkspaceDraftSubmission: Sendable, Equatable {
    public let prompt: String
    public let baseBranch: String
    public let checkout: WorkspaceCheckout?
    public let mode: WorkspaceStartMode

    private let kept: WorkspaceDraftControls?

    public init(draft: WorkspaceDraft, defaultBranch: String) {
        let checkout = draft.startingPoint.checkout
        self.prompt = WorkspaceStartAttachments.handover(isChatWorkspace: true, draft: draft.prompt, name: "")
        self.checkout = checkout
        self.baseBranch = draft.startingPoint.baseBranch
            ?? checkout?.baseBranch(default: defaultBranch)
            ?? defaultBranch
        self.mode = WorkspaceStartMode.chat(
            usesCLI: draft.controls?.usesCLIChat ?? false,
            agent: draft.controls?.agentKind ?? .claudeCode
        )
        self.kept = draft.controls
    }

    public func controls(over defaults: ComposerControls) -> ComposerControls {
        kept?.applied(to: defaults) ?? defaults
    }
}
