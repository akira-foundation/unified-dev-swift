import Foundation

extension PreviewScenarioSeeder {
    public var looseRoot: String { scratchRoot + "/loose" }

    func makeLooseFolders(_ scenario: PreviewScenario) async throws {
        let names = scenario.looseRepositories + scenario.looseFolders
        guard !names.isEmpty else { return }
        try FileManager.default.createDirectory(atPath: looseRoot, withIntermediateDirectories: true)
        for name in names {
            let path = looseRoot + "/" + name
            guard !FileManager.default.fileExists(atPath: path) else { throw WorkspaceError.pathInUse(path) }
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: false)
            try "# \(name)\n".write(toFile: path + "/NOTES.md", atomically: true, encoding: .utf8)
            guard scenario.looseRepositories.contains(name) else { continue }
            try await Git.check(Self.author + ["init", "-q", "--initial-branch=main"], in: path)
            try await Git.check(Self.author + ["add", "-A"], in: path)
            try await Git.check(Self.author + ["commit", "-q", "-m", "Start \(name)"], in: path)
        }
    }

    func seedSuggestions(_ scenario: PreviewScenario) async throws -> Int {
        let store = manager.store
        let repos = try await store.repos()
        var seeded = 0
        for project in scenario.projects {
            guard let repo = repos.first(where: { $0.path.hasSuffix("/projects/" + project.name) }) else { continue }
            let rows = try await store.workspaces(repoID: repo.id)
            for workspace in project.workspaces {
                guard let row = rows.first(where: { $0.branch == workspace.branch }) else { continue }
                let chats = try await store.sessions(workspaceID: row.id)
                for chat in workspace.chats where !chat.suggestions.isEmpty {
                    guard let session = chats.first(where: { $0.title == chat.title }) else { continue }
                    for suggestion in chat.suggestions {
                        let started = suggestion.startedIn.flatMap { name in rows.first { $0.name == name } }
                        try await seed(suggestion, in: session, of: row, startedIn: started, projects: repos)
                        seeded += 1
                    }
                }
            }
        }
        return seeded
    }

    private func seed(
        _ suggestion: PreviewScenario.Suggestion,
        in chat: Session,
        of workspace: Workspace,
        startedIn started: Workspace?,
        projects: [Repo]
    ) async throws {
        let store = manager.store
        let loose = suggestion.looseRepository ?? suggestion.looseFolder
        let named = loose.map { looseRoot + "/" + $0 } ?? suggestion.project
        guard case .success(let target) = WorkSuggestionTarget.read(
            named, callerProject: workspace.repoID, projects: projects
        ) else {
            throw PreviewScenarioError.invalid(["suggestion \"\(suggestion.title)\" names nothing Unified Dev can find"])
        }
        let admission = try await store.addWorkSuggestion(
            WorkSuggestion(
                workspaceID: workspace.id, sessionID: chat.id, title: suggestion.title,
                why: suggestion.why, prompt: suggestion.prompt, target: target
            ),
            limit: suggestion.state == .pending ? WorkSuggestion.undecidedLimit : .max
        )
        guard let added = admission.suggestion else {
            throw PreviewScenarioError.invalid(["\"\(chat.title)\" holds more suggestions than Unified Dev keeps waiting"])
        }
        let wanted: WorkSuggestion.State
        let reached: WorkSuggestion?
        switch suggestion.state {
        case .pending:
            wanted = .pending
            reached = added
        case .started:
            guard let started else {
                throw PreviewScenarioError.invalid(["suggestion \"\(suggestion.title)\" started in no workspace"])
            }
            wanted = .startedWorkspace(started.id, name: started.name)
            _ = try await store.claimWorkSuggestion(id: added.id)
            reached = try await store.settleWorkSuggestion(id: added.id, as: wanted)
        case .dismissed:
            wanted = .dismissed
            reached = try await store.dismissWorkSuggestion(id: added.id)
        case .withdrawn:
            wanted = .withdrawn
            reached = try await store.withdrawWorkSuggestion(id: added.id, by: chat.id).withdrawn
        }
        guard reached?.state == wanted else {
            throw PreviewScenarioError.invalid([
                "suggestion \"\(suggestion.title)\" could not be left \(suggestion.state.rawValue)",
            ])
        }
    }
}
