import Foundation

extension WorkSuggestionLaunch {
    public static func admit(
        _ path: String, with manager: WorkspaceManager
    ) async -> Result<Repo, WorkSuggestionRefusal> {
        switch FolderVerdict.of(await RepositoryStarter.inspect(path)) {
        case .alreadyRepository(let root):
            do {
                return .success(try await manager.addRepository(at: root))
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
