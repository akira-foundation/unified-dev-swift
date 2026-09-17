import Foundation

public struct WorkspaceStartRequest: Sendable {
    public var id: WorkspaceID
    public var repo: Repo
    public var prompt: String
    public var baseBranch: String?
    public var branch: String?
    public var name: String?
    public var checkout: WorkspaceCheckout?
    public var controls: ComposerControls?
    public var origin: WorkspaceOrigin
    public var opensSession: Bool
    public var resuming: String?
    public var setupPolicy: WorkspaceSetupPolicy

    public init(
        id: WorkspaceID = .new(),
        repo: Repo,
        prompt: String,
        origin: WorkspaceOrigin,
        baseBranch: String? = nil,
        branch: String? = nil,
        name: String? = nil,
        checkout: WorkspaceCheckout? = nil,
        controls: ComposerControls? = nil,
        opensSession: Bool = true,
        resuming: String? = nil,
        setupPolicy: WorkspaceSetupPolicy = .deferred
    ) {
        self.id = id
        self.repo = repo
        self.prompt = prompt
        self.origin = origin
        self.baseBranch = baseBranch
        self.branch = branch
        self.name = name
        self.checkout = checkout
        self.controls = controls
        self.opensSession = opensSession
        self.resuming = resuming
        self.setupPolicy = setupPolicy
    }
}

public struct StartedWorkspace: Sendable {
    public var workspace: Workspace
    public var session: Session?
    public var placeholder: String?
    public var setupSucceeded: Bool?
    public var projectCameBack: Bool

    public init(
        workspace: Workspace,
        session: Session? = nil,
        placeholder: String? = nil,
        setupSucceeded: Bool? = nil,
        projectCameBack: Bool = false
    ) {
        self.workspace = workspace
        self.session = session
        self.placeholder = placeholder
        self.setupSucceeded = setupSucceeded
        self.projectCameBack = projectCameBack
    }
}

extension WorkspaceManager {
    public func start(
        _ request: WorkspaceStartRequest,
        namer: @Sendable () async -> String? = { nil },
        setupOutput: (@Sendable (String) -> Void)? = nil
    ) async throws -> StartedWorkspace {
        let placeholder = request.name == nil && request.checkout == nil ? await namer() : nil

        let workspace = try await createWorkspace(
            id: request.id,
            repo: request.repo,
            prompt: request.prompt,
            name: request.name ?? placeholder,
            branch: request.branch,
            baseBranch: request.baseBranch,
            origin: request.origin,
            checkout: request.checkout,
            setupPolicy: request.setupPolicy
        )

        let projectCameBack = await bringProjectBack(request.repo.id)

        var session: Session?
        if request.opensSession {
            let controls = request.controls
            let backend = controls?.agentKind ?? .claudeCode
            let mode = (controls?.permissionMode ?? AppDefaults.fallbackPermissionMode)
                .nearest(on: backend)
            let opened = try await store.upsert(Session(
                workspaceID: workspace.id,
                title: PaneNaming.chat,
                agentSessionID: request.resuming,
                model: controls?.model ?? AppDefaults.fallbackModel,
                effort: controls?.effort ?? AppDefaults.fallbackEffort,
                agentKind: backend,
                permissionMode: mode,
                interactionMode: controls?.interactionMode ?? .build
            ))
            await controls?.store(sessionID: opened.id, in: store)
            session = opened
        }

        var setupSucceeded: Bool?
        if request.setupPolicy == .run {
            let port = await ensurePort(for: workspace)
            setupSucceeded = await runSetup(
                workspace: workspace, repo: request.repo, port: port
            ) { line in
                setupOutput?(line)
            }
        }

        return StartedWorkspace(
            workspace: workspace,
            session: session,
            placeholder: placeholder,
            setupSucceeded: setupSucceeded,
            projectCameBack: projectCameBack
        )
    }
}
