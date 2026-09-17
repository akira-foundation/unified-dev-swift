import SwiftUI
import Core

@MainActor
@Observable
final class CheckFailureSender {
    private(set) var sending: String?

    func isSending(_ run: CheckRun) -> Bool { sending == run.id }

    static func canSend(_ run: CheckRun) -> Bool { CheckState(run) == .failed }

    func send(_ run: CheckRun, in model: WorkspaceModel) async -> String? {
        guard sending == nil else { return nil }
        sending = run.id
        defer { sending = nil }

        let state = CheckState(run)
        var excerpt: CheckFailureHandoff.Excerpt?

        if let target = CheckFailureHandoff.logTarget(detailsURL: run.detailsURL) {
            do {
                let log = try await GitHub.checkRunLog(target, worktree: model.workspace.path)
                excerpt = CheckFailureHandoff.excerpt(log)
            } catch {
                excerpt = nil
            }
        }

        guard let excerpt else {
            return await ComposerHandoff.write(
                CheckFailureHandoff.sentence(
                    name: run.name,
                    workflow: run.workflowName,
                    state: state,
                    detailsURL: run.detailsURL
                ),
                to: model
            ).failure
        }

        let name = CheckFailureHandoff.logFilename(for: run.name)
        let outcome = await ComposerHandoff.attach(
            [.text(excerpt.text, named: name)],
            to: model
        ) { paths in
            CheckFailureHandoff.sentence(
                name: run.name,
                workflow: run.workflowName,
                state: state,
                detailsURL: run.detailsURL,
                logPath: paths.first,
                excerpt: excerpt
            )
        }
        return outcome.failure
    }
}
