import Foundation

extension WorkSuggestionLaunch {
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
