import Foundation
import Observation
import Core

@MainActor
@Observable
final class SetupRunAlert {
    static let shared = SetupRunAlert()

    struct Request: Identifiable, Equatable {
        let id = UUID()
        var model: WorkspaceModel
        var question: SetupRunConfirmation.Question

        static func == (lhs: Request, rhs: Request) -> Bool { lhs.id == rhs.id }
    }

    var request: Request?

    func ask(_ model: WorkspaceModel) {
        guard model.canRunSetup else { return }
        request = Request(
            model: model,
            question: SetupRunConfirmation.question(
                hasRunSetup: model.hasRunSetup, isAgentRunning: model.isRunning
            )
        )
    }
}
