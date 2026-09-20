import Foundation
import Core

extension AppModel {
    static let transcriptSearchDebounce = Duration.milliseconds(120)

    func startTranscriptIndexBackfill() {
        transcriptBackfillTask?.cancel()
        transcriptBackfillTask = Task { [weak self] in
            guard let store = self?.store else { return }
            while !Task.isCancelled {
                guard let progress = try? await store.indexOlderTranscripts() else { return }
                self?.isTranscriptIndexIncomplete = !progress.isFinished
                if progress.isFinished { return }
                await Task.yield()
            }
        }
    }

    func searchTranscripts(_ query: String) {
        transcriptSearchTask?.cancel()
        guard TranscriptSearch.matchExpression(for: query) != nil else {
            transcriptResults = []
            return
        }

        transcriptSearchTask = Task { [weak self] in
            try? await Task.sleep(for: Self.transcriptSearchDebounce)
            guard !Task.isCancelled, let store = self?.store else { return }
            let results = (try? await store.searchTranscripts(query)) ?? []
            guard !Task.isCancelled else { return }
            self?.transcriptResults = results
        }
    }

    func open(_ match: TranscriptMatch) async {
        pendingTranscriptTarget = TranscriptSearchTarget(
            workspaceID: match.workspaceID, sessionID: match.sessionID, seq: match.seq
        )

        if let workspace = workspaces.first(where: { $0.id == match.workspaceID }) {
            model(for: workspace).activeSessionID = match.sessionID
            selection = .workspace(workspace.id)
            return
        }

        guard let archived = await archivedWorkspaces().first(where: { $0.id == match.workspaceID })
        else { return }
        model(for: archived).activeSessionID = match.sessionID
        openArchived(archived)
    }

    func takeTranscriptTarget(
        for workspaceID: WorkspaceID, session sessionID: SessionID
    ) -> TranscriptSearchTarget? {
        guard let target = pendingTranscriptTarget,
              target.workspaceID == workspaceID, target.sessionID == sessionID
        else { return nil }
        pendingTranscriptTarget = nil
        return target
    }
}
