import Foundation

extension WorkspaceManager {
    func adoptRemoteSuggestions(for repo: Repo) async {
        guard let url = await Git.remoteURL("origin", in: repo.path),
              let slug = WorkSuggestionTarget.gitHubSlug(ofRemote: url)
        else { return }
        _ = try? await store.retargetRemoteWorkSuggestions(slug: slug, to: repo.id)
    }
}
