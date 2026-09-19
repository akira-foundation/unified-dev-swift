import Foundation

public enum CrewLaunchRefusal: Sendable, Equatable {
    case rule(Crew.StartRefusal)
    case noTask
    case unavailable(String)
    case refused(String)

    public var sentence: String {
        switch self {
        case .rule(let refusal): Crew.sentence(for: refusal)
        case .noTask: CrewToolTrouble.noTask.sentence
        case .unavailable(let message): CrewToolTrouble.unexplained(tool: CrewToolName.start, message).sentence
        case .refused(let sentence): sentence
        }
    }
}

public enum CrewLaunchOutcome: Sendable, Equatable {
    case started(sentence: String, name: String)
    case refused(CrewLaunchRefusal)
}

public enum CrewLaunch {
    public static func launch(
        name: String,
        task: String?,
        model: String?,
        effort: String?,
        from caller: Session,
        in workspaceID: WorkspaceID,
        store: Store,
        start: CrewStarting
    ) async -> CrewLaunchOutcome {
        let crew: [Session]
        do {
            crew = try await store.crew(inWorkspace: workspaceID)
        } catch {
            return .refused(.unavailable(error.readableMessage))
        }

        let accepted: String
        switch Crew.start(
            name: name,
            existing: Set(crew.map(\.title)),
            running: crew.filter(CrewCensus.isRunning).count,
            callerIsSubagent: caller.parentSessionID != nil
        ) {
        case .failure(let refusal): return .refused(.rule(refusal))
        case .success(let named): accepted = named
        }

        guard let task = AgentStartTool.text(task) else { return .refused(.noTask) }

        let order = CrewOrder(
            name: accepted,
            task: task,
            model: AgentStartTool.text(model),
            effort: AgentStartTool.text(effort)
        )
        switch await start(order, caller.id, workspaceID) {
        case .started(let sentence): return .started(sentence: sentence, name: accepted)
        case .refused(let refusal): return .refused(.refused(refusal))
        }
    }
}
