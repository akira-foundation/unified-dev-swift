import Foundation

public struct PreviewScenarioSeeder: Sendable {
    public struct Outcome: Sendable, Equatable {
        public var projects: Int
        public var workspaces: Int
        public var chats: Int
        public var quotas: Int
        public var suggestions = 0
        public var browserTabs: [BrowserTab] = []
    }

    public struct BrowserTab: Sendable, Equatable {
        public var workspaceID: WorkspaceID
        public var address: String
    }

    static let author = [
        "-c", "user.name=Preview Scenario",
        "-c", "user.email=preview@unifieddev.invalid",
        "-c", "commit.gpgsign=false",
        "-c", "tag.gpgsign=false",
        "-c", "core.hooksPath=/dev/null",
        "-c", "core.fsmonitor=false",
        "-c", "init.templateDir=",
    ]

    public let manager: WorkspaceManager
    public let scratchRoot: String

    public init(manager: WorkspaceManager, scratchRoot: String) {
        self.manager = manager
        self.scratchRoot = scratchRoot
    }

    public var projectsRoot: String { scratchRoot + "/projects" }
    public var remotesRoot: String { scratchRoot + "/remotes" }

    public func seed(_ scenario: PreviewScenario, at now: Date = Date()) async throws -> Outcome {
        let problems = scenario.problems
        guard problems.isEmpty else { throw PreviewScenarioError.invalid(problems) }
        guard try await manager.store.repos().isEmpty else { throw PreviewScenarioError.alreadySeeded }
        try await makeLooseFolders(scenario)

        var outcome = Outcome(projects: 0, workspaces: 0, chats: 0, quotas: 0)
        for project in scenario.projects {
            let path = try await makeRepository(project)
            try await publishBranches(project, at: path)
            let repo = try await manager.addRepository(at: path)
            if project.hidden { _ = try await manager.store.update(repoID: repo.id) { $0.hidden = true } }
            outcome.projects += 1
            var started: [String: WorkspaceID] = [:]
            for workspace in project.workspaces {
                let (workspaceID, chats) = try await start(workspace, in: repo, among: started)
                started[workspace.name] = workspaceID
                outcome.workspaces += 1
                outcome.chats += chats
                if let browser = workspace.browser {
                    outcome.browserTabs.append(BrowserTab(workspaceID: workspaceID, address: browser))
                }
            }
            try await publishRemoteAhead(project)
            try await slowDownRemote(project, at: path)
        }
        outcome.suggestions = try await seedSuggestions(scenario)
        if !scenario.quotas.isEmpty {
            try await manager.store.recordQuotas(scenario.quotas.map { $0.quota(at: now) })
            outcome.quotas = scenario.quotas.count
        }
        return outcome
    }

    func makeRepository(_ project: PreviewScenario.Project) async throws -> String {
        let path = projectsRoot + "/" + project.name
        let remote = remotesRoot + "/" + project.name + ".git"
        guard !FileManager.default.fileExists(atPath: path),
              !FileManager.default.fileExists(atPath: remote) else {
            throw WorkspaceError.pathInUse(FileManager.default.fileExists(atPath: path) ? path : remote)
        }
        try FileManager.default.createDirectory(atPath: projectsRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: remotesRoot, withIntermediateDirectories: true)

        try await git(["init", "-q", "--bare", "--initial-branch=main", remote], in: remotesRoot)
        try await git(["clone", "-q", remote, path], in: projectsRoot)

        try Self.write(project.files, into: path)
        let history = project.commits.isEmpty ? ["Start \(project.name)"] : project.commits
        for (index, message) in history.enumerated() {
            try await commit(message, in: path, adding: index == 0 ? "# \(project.name)\n" : nil)
        }
        try await git(["push", "-q", "-u", "origin", "main"], in: path)
        try await git(["remote", "set-head", "origin", "main"], in: path)
        return path
    }

    func publishRemoteAhead(_ project: PreviewScenario.Project) async throws {
        guard !project.remoteAhead.isEmpty else { return }
        let remote = remotesRoot + "/" + project.name + ".git"
        let upstream = remotesRoot + "/" + project.name + ".upstream"
        try await git(["clone", "-q", remote, upstream], in: remotesRoot)
        for message in project.remoteAhead {
            try await commit(message, in: upstream, adding: nil)
        }
        try await git(["push", "-q", "origin", "main"], in: upstream)
        try FileManager.default.removeItem(atPath: upstream)
    }

    func slowDownRemote(_ project: PreviewScenario.Project, at path: String) async throws {
        guard let uploadPack = project.remote.uploadPack else { return }
        try await git(["config", "remote.origin.uploadpack", uploadPack], in: path)
    }

    func publishBranches(_ project: PreviewScenario.Project, at path: String) async throws {
        guard !project.branches.isEmpty else { return }
        for branch in project.branches {
            try await git(["checkout", "-q", "-b", branch, "main"], in: path)
            try await commit("Start \(branch)", in: path, adding: nil)
            try await git(["push", "-q", "-u", "origin", branch], in: path)
        }
        try await git(["checkout", "-q", "main"], in: path)
    }

    func start(
        _ workspace: PreviewScenario.Workspace, in repo: Repo, among earlier: [String: WorkspaceID] = [:]
    ) async throws -> (WorkspaceID, Int) {
        let started = try await manager.start(WorkspaceStartRequest(
            repo: repo,
            prompt: workspace.name,
            origin: Self.origin(of: workspace, among: earlier),
            branch: workspace.branch,
            name: workspace.name,
            opensSession: workspace.chats.isEmpty,
            setupPolicy: .skip
        ))
        try Self.apply(workspace.changes, to: started.workspace.path)
        for (order, chat) in workspace.chats.enumerated() {
            let session = try await manager.store.upsert(Session(
                workspaceID: started.workspace.id,
                title: chat.title,
                sortOrder: order
            ))
            for line in chat.messages {
                _ = try await manager.store.appendNext(
                    sessionID: session.id,
                    kind: line.from == .user ? .user : .assistantText,
                    payload: try Self.payload(line.text, from: line.from)
                )
            }
        }
        return (started.workspace.id, workspace.chats.count)
    }

    static func origin(
        of workspace: PreviewScenario.Workspace, among earlier: [String: WorkspaceID]
    ) -> WorkspaceOrigin {
        guard let starter = workspace.startedBy, let parent = earlier[starter] else { return .user }
        return .agent(parentWorkspaceID: parent, spawnToolUseID: "toolu_preview_\(workspace.branch)")
    }

    static func write(_ files: [String: String], into path: String) throws {
        for (file, contents) in files.sorted(by: { $0.key < $1.key }) {
            let target = path + "/" + file
            try FileManager.default.createDirectory(
                atPath: (target as NSString).deletingLastPathComponent, withIntermediateDirectories: true
            )
            try contents.write(toFile: target, atomically: true, encoding: .utf8)
        }
    }

    static func apply(_ changes: [String: String?], to path: String) throws {
        let deleted = changes.filter { $0.value?.isEmpty ?? true }.keys.sorted()
        for file in deleted {
            try FileManager.default.removeItem(atPath: path + "/" + file)
        }
        try write(changes.compactMapValues { $0?.isEmpty == false ? $0 : nil }, into: path)
    }

    static func payload(_ text: String, from speaker: PreviewScenario.Line.Speaker) throws -> Data {
        let role = speaker == .user ? "user" : "assistant"
        let message: [String: Any] = [
            "type": role,
            "message": ["role": role, "content": [["type": "text", "text": text]]],
        ]
        return try JSONSerialization.data(withJSONObject: message, options: [.sortedKeys])
    }

    private func commit(_ message: String, in path: String, adding header: String?) async throws {
        let notes = path + "/NOTES.md"
        let existing = (try? String(contentsOfFile: notes, encoding: .utf8)) ?? (header ?? "")
        try (existing + "- \(message)\n").write(toFile: notes, atomically: true, encoding: .utf8)
        try await git(["add", "-A"], in: path)
        try await git(["commit", "-q", "-m", message], in: path)
    }

    private func git(_ arguments: [String], in directory: String) async throws {
        try await Git.check(Self.author + arguments, in: directory)
    }
}
