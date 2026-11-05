import Foundation

extension WorkSuggestionLaunch {
    public static func admit(
        _ path: String, filedAs id: WorkSuggestionID, active: ProfileID, with manager: WorkspaceManager
    ) async -> Result<Repo, WorkSuggestionRefusal> {
        do {
            guard let suggestion = try await manager.store.workSuggestion(id: id) else {
                return .failure(WorkSuggestionRefusal(WorkSuggestionWording.gone))
            }
            let source = try await manager.store.workSuggestionSource(suggestion)
            guard let profile = WorkSuggestionProfile.profile(admitting: source, active: active) else {
                return .failure(WorkSuggestionRefusal(WorkSuggestionWording.anotherProfile))
            }
            return await admit(path, profileID: profile, with: manager)
        } catch {
            return .failure(WorkSuggestionRefusal("Unified Dev could not read this suggestion: \(error.readableMessage)"))
        }
    }

    public static func admit(
        _ path: String, profileID: ProfileID, with manager: WorkspaceManager
    ) async -> Result<Repo, WorkSuggestionRefusal> {
        switch FolderVerdict.of(await RepositoryStarter.inspect(path)) {
        case .alreadyRepository(let root):
            guard FolderPath.sameFolder(root, path) else {
                return .failure(WorkSuggestionRefusal(WorkSuggestionWording.insideRepository(path, root: root)))
            }
            if let setup = await Git.ownSetup(of: root) {
                return .failure(WorkSuggestionRefusal(WorkSuggestionWording.ownSetup(root, setup)))
            }
            do {
                let project = try await manager.addRepository(at: root, profileID: profileID)
                guard project.profileID == profileID else {
                    return .failure(WorkSuggestionRefusal(BridgeProfileScope.belongsElsewhere(path: root)))
                }
                return .success(project)
            } catch {
                return .failure(WorkSuggestionRefusal(
                    "Unified Dev could not add \(root) as a project: \(error.readableMessage)"
                ))
            }
        case .refuse(let refusal):
            return .failure(WorkSuggestionRefusal(refusal.sentence))
        case .offer:
            return .failure(WorkSuggestionRefusal(WorkSuggestionWording.notARepository(path)))
        }
    }
}
