import Core

struct PendingCrewStop: Equatable {
    var sessionID: SessionID
    var workspaceID: WorkspaceID
    var name: String

    static let message =
        "It is working now, and the turn it is in the middle of is lost. Everything it has "
        + "already written in the worktree stays exactly as it is, and its conversation stays "
        + "here to read. The agent that started it is told."

    init(member: CrewRow, workspaceID: WorkspaceID) {
        sessionID = member.id
        self.workspaceID = workspaceID
        name = member.name
    }

    static func needsConfirmation(_ state: SessionState) -> Bool {
        switch state {
        case .running, .waiting: true
        case .idle, .failed, .cancelled: false
        }
    }

    @MainActor
    func stop(in app: AppModel) async {
        guard let model = app.existingModel(for: workspaceID),
              let member = model.sessions.first(where: { $0.id == sessionID })
        else { return }

        await model.closeCrewMember(member)
    }
}
