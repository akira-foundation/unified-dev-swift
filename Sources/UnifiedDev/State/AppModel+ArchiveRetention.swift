import Core
import Foundation

extension AppModel {
    func startArchiveRetention() {
        archiveRetentionTask?.cancel()
        archiveRetentionTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.deleteExpiredArchives()
                try? await Task.sleep(for: .seconds(ArchiveRetention.sweepInterval))
            }
        }
    }

    func expiredArchives(under retention: ArchiveRetention) async -> [ArchivedWorkspaceFootprint] {
        guard let store, retention.isEnabled,
              let footprints = try? await store.archivedFootprints() else { return [] }
        var protected = restoring
        if let open = selection.archivedWorkspaceID { protected.insert(open) }
        return retention.expired(in: footprints, now: Date(), protecting: protected)
    }

    private func deleteExpiredArchives() async {
        guard let store else { return }
        let retention = await ArchiveRetention.load(from: store)
        var deleted = 0
        var freed = 0
        for footprint in await expiredArchives(under: retention) {
            let outcome = await deleteArchived([footprint.id])
            if outcome.didDelete {
                deleted += 1
                freed += footprint.totalBytes
            } else if let sentence = outcome.sentence {
                Log.archive.error(
                    "could not delete expired \(footprint.workspace.name, privacy: .public): \(sentence, privacy: .public)"
                )
            }
        }
        guard deleted > 0 else { return }
        Log.archive.info("retention deleted \(deleted, privacy: .public) archived workspaces")
        notice = ArchiveRetention.notice(deleted: deleted, bytes: freed)
    }
}
