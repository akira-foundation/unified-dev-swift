import Foundation
import Core

extension AppModel {
    var activeProfile: Profile? {
        profiles.first { $0.id == activeProfileID }
    }

    var profileRepos: [Repo] {
        ProfileScope.repos(repos, in: activeProfileID)
    }

    var profileWorkspaces: [Workspace] {
        ProfileScope.workspaces(workspaces, repos: repos, in: activeProfileID)
    }

    func switchProfile(to id: ProfileID) async {
        guard ProfileNavigation.maySwitch(to: id, from: activeProfileID, among: profiles) else { return }
        adoptActiveProfile(id)
        selection = landing(in: id)
        await activeProfileWrite?.value
    }

    func createProfile(name: String, colour: String, symbol: String) async {
        guard let store else { return }
        do {
            _ = try await store.createProfile(name: name, colour: colour, symbol: symbol)
            try await reloadProfiles()
        } catch {
            alert = AppAlert(title: "Could not create the profile", message: error.readableMessage)
        }
    }

    func updateProfile(_ id: ProfileID, _ change: @Sendable (inout Profile) -> Void) async {
        guard let store else { return }
        do {
            try await store.update(profileID: id, change)
            try await reloadProfiles()
        } catch {
            alert = AppAlert(title: "Could not change the profile", message: error.readableMessage)
        }
    }

    func deleteProfile(_ id: ProfileID) async {
        guard let store else { return }
        let title = "Could not delete the profile"
        do {
            try await store.deleteProfile(id: id)
            profileMemory.forget(id)
            ProfileMemoryDefaults.save(profileMemory)
            if activeProfileID == id {
                adoptActiveProfile(.initial)
                selection = landing(in: .initial)
                await activeProfileWrite?.value
            }
            try await reloadProfiles()
        } catch let refusal as ProfileDeletionRefused {
            alert = AppAlert(title: title, message: refusal.sentence)
        } catch {
            alert = AppAlert(title: title, message: error.readableMessage)
        }
    }

    func moveProject(_ repoID: RepoID, to profile: ProfileID) async {
        guard let store else { return }
        let title = "Could not move the project"
        do {
            try await store.move(repoID: repoID, to: profile)
            await reload()
        } catch let refusal as ProfileMoveRefused {
            alert = AppAlert(title: title, message: refusal.sentence)
        } catch {
            alert = AppAlert(title: title, message: error.readableMessage)
        }
    }

    func restoreLastSelection() {
        guard case .home = selection else { return }
        selection = landing(in: activeProfileID)
    }

    func activateProfile(showing selection: SidebarSelection) {
        guard let owner = ProfileNavigation.activation(
            for: selection, active: activeProfileID, workspaces: rows(naming: selection), repos: repos
        ) else { return }
        adoptActiveProfile(owner)
    }

    func activateProfile(showing filter: HomeFilter) {
        guard let owner = ProfileNavigation.activation(forHome: filter, active: activeProfileID, repos: repos) else {
            return
        }
        adoptActiveProfile(owner)
    }

    func rememberInActiveProfile(_ selection: SidebarSelection) {
        guard let id = selection.workspaceID else { return }
        profileMemory.remember(id, in: activeProfileID)
        ProfileMemoryDefaults.save(profileMemory)
    }

    func settleSelectionInActiveProfile() {
        narrowHomeFilterToActiveProfile()
        guard let landing = ProfileNavigation.settled(
            selection,
            active: activeProfileID,
            memory: profileMemory,
            workspaces: rows(naming: selection),
            repos: repos
        ) else { return }
        selection = landing
    }

    func narrowHomeFilterToActiveProfile() {
        let narrowed = ProfileNavigation.narrowed(homeFilter, to: activeProfileID, repos: repos)
        if homeFilter != narrowed { homeFilter = narrowed }
    }

    func saveActiveProfile(_ id: ProfileID) {
        guard let store else { return }
        let earlier = activeProfileWrite
        activeProfileWrite = Task { [weak self] in
            await earlier?.value
            do {
                try await store.setActiveProfile(id)
            } catch {
                self?.alert = AppAlert(title: "Could not remember the profile", message: error.readableMessage)
            }
        }
    }

    private func landing(in profile: ProfileID) -> SidebarSelection {
        ProfileNavigation.landing(in: profile, memory: profileMemory, workspaces: workspaces, repos: repos)
    }

    private func rows(naming selection: SidebarSelection) -> [Workspace] {
        guard let id = selection.archivedWorkspaceID, let row = workspaceModels[id]?.workspace else {
            return workspaces
        }
        return workspaces + [row]
    }
}
