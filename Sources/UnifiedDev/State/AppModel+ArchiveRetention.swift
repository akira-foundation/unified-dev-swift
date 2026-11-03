import Core
import Foundation

extension AppModel {
    func startArchiveRetention() {
        archiveRetentionTask?.cancel()
        archiveRetentionTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    guard let self else { return }
                    await self.deleteExpiredArchives()
                }
                try? await Task.sleep(for: .seconds(ArchiveRetention.sweepInterval))
            }
        }
    }

    func expiredArchives(under retention: ArchiveRetention) async -> [ArchivedWorkspaceFootprint] {
        guard let store, retention.isEnabled,
              let footprints = try? await store.archivedFootprints(),
              let holding = try? await store.workspacesHoldingUndeliveredMessages() else { return [] }
        return retention.expired(in: footprints, now: Date(), protecting: archivesInUse.union(holding))
    }

    private var archivesInUse: Set<WorkspaceID> {
        var inUse = restoring.union(carryingOn)
        if let open = selection.archivedWorkspaceID { inUse.insert(open) }
        return inUse
    }

    private func deleteExpiredArchives() async {
        guard let store else { return }
        let retention = await ArchiveRetention.load(from: store)
        var deleted: [ArchivedWorkspaceFootprint] = []
        for footprint in await expiredArchives(under: retention) {
            guard !Task.isCancelled, await ArchiveRetention.load(from: store) == retention else { break }
            guard !archivesInUse.contains(footprint.id) else { continue }
            let outcome = await removeArchivedRecords([footprint.id])
            if outcome.didDelete {
                deleted.append(footprint)
                Log.archive.info("retention deleted \(footprint.workspace.name, privacy: .public)")
            } else if let sentence = outcome.sentence {
                Log.archive.error(
                    "could not delete expired \(footprint.workspace.name, privacy: .public): \(sentence, privacy: .public)"
                )
            }
        }
        guard let notice = ArchiveRetention.notice(deleted: deleted) else { return }
        invalidateArchived()
        self.notice = notice
    }
}
