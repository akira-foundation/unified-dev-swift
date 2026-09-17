import Core

extension AppModel {
    func addRepository(at path: String, presentedIn surface: ProjectSetupSurface = .main) async {
        guard manager != nil else { return }

        let facts = await RepositoryStarter.inspect(path)
        switch FolderVerdict.of(facts) {
        case .alreadyRepository(let root):
            await addKnownRepository(at: root)

        case .refuse(let refusal):
            alert = AppAlert(title: "Unified Dev will not add this folder", message: refusal.sentence)

        case .offer:
            await offerToStartRepository(at: facts.path, presentedIn: surface)
        }
    }

    @discardableResult
    private func addKnownRepository(at path: String) async -> Repo? {
        guard let manager else { return nil }
        do {
            return try await manager.addRepository(at: path)
        } catch {
            alert = AppAlert(title: "Could not add that folder", message: error.readableMessage)
            return nil
        }
    }

    func addStartedProject(at path: String) async -> Repo? {
        await addKnownRepository(at: path)
    }

    private func offerToStartRepository(at path: String, presentedIn surface: ProjectSetupSurface) async {
        let contents = await Task.detached { RepositoryStarter.scan(path) }.value
        let identityProblem = await RepositoryStarter.identityProblem(at: path)

        ProjectSetup.shared.present(ProjectSetup.Request(
            path: path,
            contents: contents,
            surface: surface,
            identityProblem: identityProblem
        ))
    }

    func finishProjectSetup(_ path: String?) async {
        ProjectSetup.shared.dismiss()
        guard let path else { return }
        await addKnownRepository(at: path)
    }

    func projectRemoval(_ repo: Repo) -> Confirmation {
        let mine = workspaces.filter { $0.repoID == repo.id }
        return ProjectRemoval.confirmation(
            for: repo,
            workspaces: mine,
            runningAgents: mine.count { isRunning($0) }
        )
    }

    func removeRepository(_ repo: Repo) async {
        guard let store else { return }
        do {
            try await store.requireRepoCanBeRemoved(id: repo.id)
        } catch {
            alert = AppAlert(title: "Could not remove the project", message: error.readableMessage)
            return
        }

        let doomed = workspaceModels.filter { $0.value.workspace.repoID == repo.id }
        for (_, model) in doomed { model.stopEverything() }
        for (id, model) in doomed {
            await model.shutdown()
            model.teardown()
            workspaceModels[id] = nil
        }

        do {
            try await store.deleteRepo(id: repo.id)
        } catch {
            alert = AppAlert(
                title: "Could not remove the project",
                message: TranscriptStanding.complaint(about: error)
            )
        }
    }

    func toggleCollapsed(_ repo: Repo) async {
        guard let store else { return }
        _ = try? await store.update(repoID: repo.id) { $0.collapsed.toggle() }
    }

    func toggleHidden(_ repo: Repo) async {
        guard let store else { return }
        _ = try? await store.update(repoID: repo.id) { $0.hidden.toggle() }
    }

    func rename(_ repo: Repo, to name: String) async {
        guard let store, !name.isEmpty else { return }
        _ = try? await store.update(repoID: repo.id) { $0.name = name }
    }
}
