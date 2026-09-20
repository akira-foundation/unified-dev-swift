import Foundation

public typealias WorkspaceStarting =
    @Sendable (AgentWorkspaceOrder, Repo, BridgeIdentity, WorkspaceOrigin) async throws
        -> StartedWorkspaceSummary

public typealias PullRequestCheckoutResolving =
    @Sendable (_ reference: String, _ repoPath: String) async -> WorkspaceCheckoutResolution

public struct WorkspaceStartTool: BridgeToolHandling {
    private let start: WorkspaceStarting
    private let resolvePullRequest: PullRequestCheckoutResolving

    public init(
        start: @escaping WorkspaceStarting,
        resolvePullRequest: @escaping PullRequestCheckoutResolving = {
            await WorkspaceCheckoutResolver.resolve($0, repoPath: $1)
        }
    ) {
        self.start = start
        self.resolvePullRequest = resolvePullRequest
    }

    public let roles: Set<BridgeRole> = [.parent, .owner]

    public let tool = BridgeTool(
        name: "workspace_start",
        description: """
            Start a workspace and give it a task. It is a real git worktree on its own branch with \
            its own agent, and it appears in Unified Dev's sidebar for the owner to watch and review.

            Name the project to start it in with 'project', giving the name or the path that \
            project_list reports. Unified Dev only starts workspaces in repositories it already has, \
            and registering a new one with project_add is the owner's to do. If you are yourself \
            running inside a Unified Dev workspace, leave 'project' out to start it in the project \
            you are already in, or name another project to hand the work to that repository \
            instead. The new workspace is still counted as one you started.

            Use it when a task splits into parts that do not need to see each other's edits, and \
            you want them worked on at the same time rather than one after another.

            There are two ways to start it, the two Unified Dev's own create window offers, and picking \
            the wrong one is the mistake worth avoiding here.

            '\(WorkspaceSourceTab.newBranch.title)' is the default and needs nothing said. \
            \(WorkspaceSourceTab.newBranch.explanation) Name the branch to cut from with \
            'base_branch', or leave it out for the project's default branch.

            '\(WorkspaceSourceTab.existingBranch.title)' is 'existing_branch'. \
            \(WorkspaceSourceTab.existingBranch.explanation) Use it to carry on, review or fix \
            work that is already on a branch: cutting a new branch off that branch instead gives \
            you a workspace whose diff is empty, because it starts out identical to the branch \
            you named. The branch has to exist already, and git allows one worktree per branch, \
            so a branch another workspace is sitting on is refused rather than opened twice.

            To review an existing GitHub pull request, use 'pull_request' with its number, '#123', \
            or its GitHub URL. Unified Dev checks out the pull request itself, preserving its base and \
            identity so the Changes, Checks and Merge controls refer to that pull request. Do not \
            create a review branch with base_branch for this purpose.

            Name only one of base_branch, existing_branch or pull_request.

            It returns as soon as the workspace exists, not when its work is done. The new agent \
            starts on its own and keeps running while you carry on. There is no way to wait for \
            it from here, so do not ask for one and then sit idle: say what you started and get on \
            with your own work.

            The task you give it is all it gets. It cannot see this conversation, so write the \
            prompt as if to someone who has just opened the project for the first time.

            This costs real money and real disk. Start one because the work genuinely divides, \
            not to parallelise something you could do in a single pass. A workspace that was \
            itself started this way cannot start others.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "project": .object([
                    "type": .string("string"),
                    "description": .string(
                        "Which project to start it in, by the name or the path project_list "
                            + "reports. Inside a Unified Dev workspace, leave it out for the project "
                            + "you are in, or name another to start the work there."
                    ),
                ]),
                "prompt": .object([
                    "type": .string("string"),
                    "description": .string(
                        "The task, written for someone with no context beyond the project itself."
                    ),
                ]),
                "name": .object([
                    "type": .string("string"),
                    "description": .string(
                        "What to call it in the sidebar. Leave it out and Unified Dev names it from the task."
                    ),
                ]),
                "base_branch": .object([
                    "type": .string("string"),
                    "description": .string(
                        "Cut a new branch from this one. Your commits land on the new branch and "
                            + "merge back into this one. Leave it out for the project's default "
                            + "branch. Do not name it together with existing_branch."
                    ),
                ]),
                "existing_branch": .object([
                    "type": .string("string"),
                    "description": .string(
                        "Work on this branch itself, instead of cutting a new one. Your commits "
                            + "land on it. It has to exist already, locally or on the remote, and "
                            + "it must not be open in another workspace. Do not name it together "
                            + "with base_branch."
                    ),
                ]),
                "pull_request": .object([
                    "type": .string("string"),
                    "description": .string(
                        "Open this GitHub pull request itself for review, by number, #number or "
                            + "GitHub URL. This preserves the PR connection so Unified Dev can show "
                            + "checks and merge it. Do not combine it with base_branch or "
                            + "existing_branch."
                    ),
                ]),
                "agent": .object([
                    "type": .string("string"),
                    "enum": .array(AgentKind.runnable.map { .string($0.rawValue) }),
                    "description": .string(
                        "Which agent runs it. Leave it out for the one you are running on, or "
                            + "for Unified Dev's own default if you are not running in Unified Dev."
                    ),
                ]),
                "model": .object([
                    "type": .string("string"),
                    "description": .string(
                        "The exact model id. Claude Code models are opus, sonnet, fable and "
                            + "haiku. Codex model ids come from the signed-in Codex account, for "
                            + "example gpt-5.6-sol. Do not use a Claude Code model with codex or "
                            + "a Codex model with claudeCode. Leave this out to use the selected "
                            + "agent's default model."
                    ),
                ]),
            ]),
            "required": .array([.string("prompt")]),
        ])
    )

    public func call(
        _ request: MCPRequest,
        as identity: BridgeIdentity,
        store: Store
    ) async -> BridgeToolResult {
        guard let prompt = request.stringParam("prompt"),
              !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return .failure("workspace_start needs a prompt saying what the new workspace should do.")
        }

        let agent = agent(in: request)
        if let requested = request.stringParam("agent"), agent == nil {
            return .failure(
                "Unified Dev cannot run '\(requested)'. It runs "
                    + AgentKind.runnable.map(\.rawValue).joined(separator: " and ")
                    + ". Leave the argument out to use the same agent you are running on."
            )
        }

        let project: Repo
        let parent: Caller?
        switch await resolve(request, as: identity, store: store) {
        case .refused(let sentence): return .failure(sentence)
        case let .resolved(repo, caller):
            project = repo
            parent = caller
        }

        let source: AgentStartSource
        switch AgentStartRequest.read(
            baseBranch: filled(request.param("base_branch")),
            existingBranch: filled(request.param("existing_branch")),
            pullRequest: filled(request.param("pull_request"))
        ) {
        case .refused(let sentence):
            return .failure(sentence)
        case .newBranch(let ref):
            source = .newBranch(from: ref)
        case .existingBranch(let named):
            let branches = await AgentStartBranch.listing(of: project, store: store)
            switch AgentStartBranch.find(named, among: branches, project: project.name) {
            case .refused(let sentence): return .failure(sentence)
            case .found(let branch): source = .existingBranch(branch)
            }
        case .pullRequest(let reference):
            switch await resolvePullRequest(reference, project.path) {
            case .failure(let sentence): return .failure(sentence)
            case .checkout(.pullRequest(let request)): source = .pullRequest(request)
            case .checkout(.branch):
                return .failure("Unified Dev resolved that pull request as a branch instead of a pull request.")
            }
        }

        let order = AgentWorkspaceOrder(
            prompt: prompt,
            name: WorkspaceName.given(request.stringParam("name")),
            source: source,
            agent: agent,
            model: filled(request.param("model"))
        )
        let origin = origin(of: order, project: project, parent: parent)

        let launch = AgentWorkspaceLaunch(start: start)
        switch await launch.launch(order, in: project, as: identity, origin: origin, store: store) {
        case .alreadyStarted(let existing):
            return .json(.object([
                "workspace_id": .string(existing.id.rawValue),
                "name": .string(existing.name),
                "branch": .string(existing.branch),
                "path": .string(existing.path),
                "state": .string("already_started"),
                "note": .string(
                    "You already asked for this one and it exists. Nothing new was created."
                ),
            ]))

        case .started(let started):
            return .json(.object([
                "workspace_id": .string(started.workspaceID.rawValue),
                "name": .string(started.name),
                "branch": .string(started.branch),
                "path": .string(started.path),
                "state": .string("starting"),
                "note": .string(startedNote(for: identity.role)),
            ]))

        case .refused(let refusal):
            return .failure(refusal.sentence)
        }
    }

    private func startedNote(for role: BridgeRole) -> String {
        let opening = "It is setting up and will start on its own. It does not report back, and "
            + "you cannot wait for it from here. Carry on with your own work."
        guard role == .owner else { return opening }
        return opening + " When you want to know what became of it, call workspace_list."
    }

    func filled(_ value: JSONValue?) -> String? {
        guard let text = value?.stringValue else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func agent(in request: MCPRequest) -> AgentKind? {
        guard let raw = request.stringParam("agent") else { return nil }
        guard let kind = AgentKind(rawValue: raw), kind.canRunWorkspaces else { return nil }
        return kind
    }
}
