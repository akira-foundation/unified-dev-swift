import Foundation
import Core

extension AppModel {
    func startProjectIconSearch() {
        iconSearchTask?.cancel()
        iconSearchTask = Task { [weak self] in
            await self?.searchForMissingProjectIcons()
        }
    }

    private func searchForMissingProjectIcons() async {
        guard let store else { return }
        let pending = RepoIconRefresh.toSearch(repos)
        guard !pending.isEmpty else { return }

        let started = Date()
        var found = 0
        for project in pending {
            guard !Task.isCancelled else { return }
            let path = project.path
            let candidate = await Task.detached(priority: .utility) {
                RepoIconDetector.detect(in: path)
            }.value
            guard !Task.isCancelled else { return }

            if await adopt(RepoIconAnswer(found: candidate), for: project, in: store) {
                found += candidate == nil ? 0 : 1
            }
        }
        Log.icons.info(
            """
            searched \(pending.count, privacy: .public) project(s) for artwork, \
            found \(found, privacy: .public), \
            in \(Int(Date().timeIntervalSince(started) * 1000), privacy: .public)ms
            """
        )
    }

    private func adopt(_ answer: RepoIconAnswer, for project: Repo, in store: Store) async -> Bool {
        let searchedSource = project.iconSource
        let searchedPath = project.iconPath
        let stored = try? await store.update(repoID: project.id) { row in
            guard row.iconSource == searchedSource, row.iconPath == searchedPath else { return }
            guard answer.changes(row) else { return }
            answer.apply(to: &row)
        }
        guard let row = stored,
              row.iconPath == answer.iconPath, row.iconSource == answer.iconSource,
              answer.changes(project)
        else { return false }

        RepoIconArt.forget(searchedPath)
        RepoIconArt.forget(answer.iconPath)

        adoptProjectIcon(answer.iconPath, source: answer.iconSource, forRepoID: project.id)
        return true
    }
}
