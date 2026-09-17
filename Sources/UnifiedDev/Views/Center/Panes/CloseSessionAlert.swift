import SwiftUI
import Observation
import Core

@MainActor
@Observable
final class CloseSessionAlert {
    static let shared = CloseSessionAlert()

    struct Request: Identifiable, Equatable {
        let id = UUID()
        var session: Session
        var model: WorkspaceModel
        var cost: SessionClosure

        var title: String { cost.title(of: session.title) }

        var message: String { cost.reasons.joined(separator: "\n\n") }

        static func == (lhs: Request, rhs: Request) -> Bool { lhs.id == rhs.id }
    }

    var request: Request?

    func close(_ session: Session, in model: WorkspaceModel) {
        let cost = SessionClosure.closing(
            isRunning: model.isRunning(session),
            otherConversations: model.sessions.count - 1
        )
        guard cost.needsConfirmation else { return perform(session, in: model) }
        request = Request(session: session, model: model, cost: cost)
    }

    func confirm() {
        guard let request else { return }
        self.request = nil
        perform(request.session, in: request.model)
    }

    func cancel() {
        request = nil
    }

    private func perform(_ session: Session, in model: WorkspaceModel) {
        Task {
            await model.closeSession(session)
            WorkspaceTabsStore.shared.forget(.chat(session.id), workspaceID: model.workspace.id)
        }
    }
}
