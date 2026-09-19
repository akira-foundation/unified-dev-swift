import Foundation
import Testing
@testable import Core

final class WorkSuggestionLaunchSeams: @unchecked Sendable {
    let store: Store
    var orders: [AgentWorkspaceOrder] = []
    var projects: [Repo] = []
    var identities: [BridgeIdentity] = []
    var origins: [WorkspaceOrigin] = []
    var crewOrders: [CrewOrder] = []
    var crewRecordsItsChat = true
    var admitted: [String] = []
    var admission: Result<Repo, WorkSuggestionRefusal> = .failure(WorkSuggestionRefusal("No folder was expected."))

    init(store: Store) {
        self.store = store
    }

    func launch() -> WorkSuggestionLaunch {
        WorkSuggestionLaunch(
            start: { [self] order, project, identity, origin in
                orders.append(order)
                projects.append(project)
                identities.append(identity)
                origins.append(origin)
                return StartedWorkspaceSummary(
                    workspaceID: WorkspaceID("w-born-\(orders.count)"), name: order.name ?? "Born",
                    branch: "claude/born", path: "/tmp/born"
                )
            },
            crew: { [self] order, caller, workspace in
                crewOrders.append(order)
                if crewRecordsItsChat {
                    _ = try? await store.upsert(Session(workspaceID: workspace, parentSessionID: caller, title: order.name))
                }
                return .started("Started.")
            },
            admit: { [self] path in
                admitted.append(path)
                return admission
            }
        )
    }
}

struct WorkSuggestionLaunchFixture {
    let store: Store
    let repo: Repo
    let workspace: Workspace
    let chat: Session

    static func make(_ label: String) async throws -> WorkSuggestionLaunchFixture {
        let store = try makeTestStore(label)
        let repo = try await store.upsert(Repo(name: "lantern", path: "/tmp/lantern", defaultBranch: "main"))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "Importer", branch: "importer",
            path: "/tmp/lantern-importer", baseBranch: "main"
        ))
        let chat = try await store.upsert(Session(workspaceID: workspace.id, title: "Import"))
        return WorkSuggestionLaunchFixture(store: store, repo: repo, workspace: workspace, chat: chat)
    }

    func suggest(
        target: WorkSuggestion.Target = .sameProject,
        from source: Session? = nil,
        prompt: String = "Make the parser keep the last row."
    ) async throws -> WorkSuggestion {
        let chat = source ?? self.chat
        let admission = try await store.addWorkSuggestion(WorkSuggestion(
            workspaceID: chat.workspaceID, sessionID: chat.id, title: "Keep the last row",
            why: "The parser drops the last row.", prompt: prompt, target: target
        ))
        return try #require(admission.suggestion)
    }
}

extension WorkSuggestionLaunch.Outcome {
    var startedSuggestion: WorkSuggestion? {
        guard case .started(let suggestion) = self else { return nil }
        return suggestion
    }
}
