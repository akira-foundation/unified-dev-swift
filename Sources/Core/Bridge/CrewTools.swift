import Foundation

enum CrewToolName {
    static let start = "agent_start"
    static let say = "agent_say"
    static let list = "agent_list"
    static let stop = "agent_stop"
}

enum CrewCensus {
    static func isRunning(_ session: Session) -> Bool {
        switch session.state {
        case .running, .waiting: true
        case .idle, .failed, .cancelled: false
        }
    }
}

public enum CrewLookup: Sendable {
    public enum Outcome: Sendable, Equatable {
        case found(Session)
        case unknown
        case ambiguous([Session])
    }

    public static func find(_ query: String, among crew: [Session]) -> Outcome {
        guard let name = Crew.normalisedName(query) else { return .unknown }

        if let exact = crew.first(where: { $0.title == name }) { return .found(exact) }

        let matches = crew.filter { $0.title.caseInsensitiveCompare(name) == .orderedSame }
        switch matches.count {
        case 0: return .unknown
        case 1: return .found(matches[0])
        default: return .ambiguous(matches)
        }
    }
}

struct CrewCaller {
    let session: Session
    let workspaceID: WorkspaceID

    var isCrewMember: Bool { session.parentSessionID != nil }

    var crewAnchor: SessionID { session.parentSessionID ?? session.id }

    static func resolve(
        _ identity: BridgeIdentity,
        store: Store,
        tool: String
    ) async -> Result<CrewCaller, CrewToolTrouble> {
        guard let sessionID = identity.sessionID, let workspaceID = identity.workspaceID else {
            return .failure(.notInAWorkspace(tool: tool))
        }

        do {
            guard let session = try await store.session(id: sessionID) else {
                return .failure(.callerHasGone(tool: tool))
            }
            return .success(CrewCaller(session: session, workspaceID: workspaceID))
        } catch {
            return .failure(.unexplained(tool: tool, error.readableMessage))
        }
    }
}

public enum CrewToolTrouble: Error, Sendable, Equatable {
    case notInAWorkspace(tool: String)
    case callerHasGone(tool: String)
    case noTask
    case noMessage
    case noNameToStop
    case talkedSideways(given: String, orchestrator: String?)
    case saidToNobody
    case unknownMember(tool: String, given: String, known: [String])
    case ambiguousMember(tool: String, given: String)
    case stoppingIsTheOrchestratorsCall
    case unexplained(tool: String, String)

    public var sentence: String {
        switch self {
        case .notInAWorkspace(let tool):
            return BridgeWorkspaceScope.refusal(
                tool: tool, doing: "is about the agents working in"
            )

        case .callerHasGone(let tool):
            return """
                Unified Dev no longer has the chat this connection speaks for, so \(tool) cannot tell \
                whose crew you mean. Its row has gone, which retrying will not undo.
                """

        case .noTask:
            return """
                agent_start needs a 'task'. It becomes the first message in the new agent's chat \
                and it is everything that agent gets, because it cannot see this conversation. \
                Write it to the agent rather than about it, and say what finished looks like.
                """

        case .noMessage:
            return """
                agent_say needs a 'message' to deliver and it cannot be blank. There is nothing \
                on this side of the socket to type one into.
                """

        case .noNameToStop:
            return """
                agent_stop needs the 'name' of the subagent to stop. Call agent_list for the \
                names you may use.
                """

        case let .talkedSideways(given, orchestrator):
            let target = orchestrator.map { "\"\($0)\"" } ?? "the agent that started you"
            return """
                You are a subagent, so \(target) is the only agent you can talk to, and \
                '\(given)' is not it. Leave 'to' out and your message goes up. If a crewmate of \
                yours needs to hear something, say it upwards and let the agent that started you \
                both decide.
                """

        case .saidToNobody:
            return """
                agent_say needs 'to': the name of the subagent to say it to. Call agent_list for \
                the names of yours. Only a subagent may leave it out, because a subagent has \
                exactly one agent it can talk to.
                """

        case let .unknownMember(tool, given, known):
            guard !known.isEmpty else {
                return """
                    You have started no subagents, so there is none called '\(given)' for \(tool) \
                    to reach. Retrying will not change that: agent_start is how a crew begins.
                    """
            }
            return """
                You have no subagent called '\(given)'. Yours are: \
                \(BridgeWorkspaceLookup.list(known)). Retrying with the same name will fail the \
                same way, so call agent_list and use a name from its answer.
                """

        case let .ambiguousMember(tool, given):
            return """
                Two of your subagents answer to '\(given)' with only their capitals to tell them \
                apart, so \(tool) would be acting on one you did not name. Write the name exactly \
                as agent_list prints it.
                """

        case .stoppingIsTheOrchestratorsCall:
            return """
                agent_stop stops the subagents you started yourself, and you are a subagent: you \
                started none. If one of the agents on this job should stop, say so to the agent \
                that started you and let it decide.
                """

        case let .unexplained(tool, message):
            return "Unified Dev could not complete \(tool): \(message)"
        }
    }
}

public struct AgentStartTool: BridgeToolHandling {
    private let start: CrewStarting

    public init(_ start: @escaping CrewStarting) {
        self.start = start
    }

    public let roles: Set<BridgeRole> = [.parent]

    public let tool = BridgeTool(
        name: CrewToolName.start,
        description: """
            Start a subagent: a second agent, with a chat of its own, working in the workspace you \
            are already in. You give it a task, you can talk to it whenever you like, and Unified Dev \
            tells you when it has stopped and what it last said.

            This is not the Task tool, and the difference is the whole reason to be here. A Task \
            subagent lives inside one turn of yours, cannot be spoken to once it is running, and \
            is gone when that turn ends. An agent started here gets its own chat and its own row \
            in Unified Dev's sidebar, keeps its context from one turn to the next, takes more work from \
            you at any time through agent_say, and is still there when this turn is over. Start \
            one here when the work outlives a single turn, or when you will want to talk to the \
            agent again. Use the Task tool for a one-shot read that has to answer inside this turn.

            It shares this worktree and this branch. Everything you and it do lands in one diff \
            and one pull request, which is the point of it: use it when a job splits into parts \
            that have to end up as one change, such as one agent reading a large area while you \
            write, or one keeping the tests green while you work on the next thing.

            If the work needs its own branch and its own pull request, this is the wrong tool. \
            Use workspace_start, which cuts a worktree of its own for it.

            'name' is required and is yours to invent. Make it short and make it say what the \
            agent is for, such as 'tests' or 'read-the-cascade': it is what the sidebar draws, it \
            is the address agent_say and agent_stop take, and it has to be unique in this \
            workspace.

            'task' is required and is everything the agent gets. It cannot see this conversation, \
            so write it as if to somebody who has just opened the project, and say what finished \
            looks like. Because you are both editing the same files, say which files or which \
            area are its, and keep off them yourself.

            'model' and 'effort' are optional and default to the ones you are running on.

            It returns as soon as the agent has started, not when its work is done. You are told \
            when it stops and what it last said, so do not sit and wait for it: say what you \
            started and get on with your own work.

            \(Crew.tidyHint)

            Up to \(Crew.ceiling) subagents may run in one workspace at once. Each costs real \
            money and puts another writer in your working tree, so start one because the work \
            genuinely divides rather than because there is a slot free. A subagent cannot start \
            subagents of its own.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "name": .object([
                    "type": .string("string"),
                    "description": .string(
                        "What to call it. Short, unique in this workspace, and about what the "
                            + "agent is for. This is how you address it afterwards."
                    ),
                ]),
                "task": .object([
                    "type": .string("string"),
                    "description": .string(
                        "The brief, written for somebody who cannot see this conversation. Say "
                            + "which files are the agent's, and what finished looks like."
                    ),
                ]),
                "model": .object([
                    "type": .string("string"),
                    "description": .string(
                        "Which model it runs on. Leave it out for the one you are running on."
                    ),
                ]),
                "effort": .object([
                    "type": .string("string"),
                    "description": .string(
                        "How hard it thinks. Leave it out for the setting you are running on."
                    ),
                ]),
            ]),
            "required": .array([.string("name"), .string("task")]),
        ])
    )

    public func call(
        _ request: MCPRequest,
        as identity: BridgeIdentity,
        store: Store
    ) async -> BridgeToolResult {
        let caller: CrewCaller
        switch await CrewCaller.resolve(identity, store: store, tool: CrewToolName.start) {
        case .failure(let trouble): return .failure(trouble.sentence)
        case .success(let resolved): caller = resolved
        }

        switch await CrewLaunch.launch(
            name: request.stringParam("name") ?? "",
            task: request.stringParam("task"),
            model: request.stringParam("model"),
            effort: request.stringParam("effort"),
            from: caller.session,
            in: caller.workspaceID,
            store: store,
            start: start
        ) {
        case .started(let sentence, _): return BridgeToolResult(text: sentence)
        case .refused(let refusal): return .failure(refusal.sentence)
        }
    }

    static func text(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }
}

public struct AgentSayTool: BridgeToolHandling {
    private let say: CrewSaying

    public init(_ say: @escaping CrewSaying) {
        self.say = say
    }

    public let roles: Set<BridgeRole> = [.parent]

    public let tool = BridgeTool(
        name: CrewToolName.say,
        description: """
            Say something to another agent working in this workspace: one of the subagents you \
            started with agent_start, or, if you are yourself one, the agent that started you.

            This is the thing a Task subagent cannot give you. An agent started with agent_start \
            is a chat that is still there between your turns, so you can hand it what you have \
            just found, change what it is doing, or answer a question it asked you, at any point \
            in the job rather than only in the turn that started it.

            If you started subagents, 'to' is the name of the one you mean and is required.

            If you are yourself a subagent, leave 'to' out: your message goes to the agent that \
            started you, which is the only agent you can talk to. Say what you have found and \
            what you need. You cannot address the other subagents on this job, so anything they \
            need to hear goes up and comes back down.

            The message lands in that agent's chat and starts a turn there, exactly as though the \
            owner had typed it, so write it as a message rather than as a report about one. It \
            returns once the message has been delivered, not once the agent has answered.

            Speaking to an agent whose turn has ended sets it working again, so it takes one of \
            the \(Crew.ceiling) running slots this workspace has. If they are all taken, stop one \
            with agent_stop first, or wait for one to finish.

            An agent you have called agent_stop on is finished with, and its name is gone: it \
            cannot be spoken to, and agent_start is what starts another one.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "to": .object([
                    "type": .string("string"),
                    "description": .string(
                        "Which of your subagents to say it to, by the name agent_list prints. "
                            + "Required from the agent that started them. Leave it out if you "
                            + "are a subagent: your message goes to the agent above you."
                    ),
                ]),
                "message": .object([
                    "type": .string("string"),
                    "description": .string("What to say, written to that agent."),
                ]),
            ]),
            "required": .array([.string("message")]),
        ])
    )

    public func call(
        _ request: MCPRequest,
        as identity: BridgeIdentity,
        store: Store
    ) async -> BridgeToolResult {
        guard let message = AgentStartTool.text(request.stringParam("message")) else {
            return .failure(CrewToolTrouble.noMessage.sentence)
        }

        let caller: CrewCaller
        switch await CrewCaller.resolve(identity, store: store, tool: CrewToolName.say) {
        case .failure(let trouble): return .failure(trouble.sentence)
        case .success(let resolved): caller = resolved
        }

        let named = AgentStartTool.text(request.stringParam("to"))

        let target: String?
        if caller.isCrewMember {
            switch await talkingUp(named: named, caller: caller, store: store) {
            case .failure(let trouble): return .failure(trouble.sentence)
            case .success: target = nil
            }
        } else {
            switch await talkingDown(named: named, caller: caller, store: store) {
            case .failure(let trouble): return .failure(trouble.sentence)
            case .success(let member):
                if let refusal = await roomToWake(member, caller: caller, store: store) {
                    return .failure(refusal)
                }
                target = member.title
            }
        }

        switch await say(target, message, caller.session.id, caller.workspaceID) {
        case .delivered(let sentence): return BridgeToolResult(text: sentence)
        case .refused(let refusal): return .failure(refusal)
        }
    }

    private func talkingUp(
        named: String?,
        caller: CrewCaller,
        store: Store
    ) async -> Result<Void, CrewToolTrouble> {
        guard let named else { return .success(()) }

        guard let parentID = caller.session.parentSessionID else { return .success(()) }
        let orchestrator: Session?
        do {
            orchestrator = try await store.session(id: parentID)
        } catch {
            return .failure(.unexplained(tool: CrewToolName.say, error.readableMessage))
        }

        guard let orchestrator,
              Crew.normalisedName(named)?.caseInsensitiveCompare(orchestrator.title) == .orderedSame
        else {
            return .failure(.talkedSideways(given: named, orchestrator: orchestrator?.title))
        }

        return .success(())
    }

    private func roomToWake(
        _ member: Session,
        caller: CrewCaller,
        store: Store
    ) async -> String? {
        guard !CrewCensus.isRunning(member) else { return nil }

        let crew: [Session]
        do {
            crew = try await store.crew(inWorkspace: caller.workspaceID)
        } catch {
            return CrewToolTrouble.unexplained(
                tool: CrewToolName.say, error.readableMessage
            ).sentence
        }

        let running = crew.filter(CrewCensus.isRunning).count
        guard running >= Crew.ceiling else { return nil }

        return Crew.sentence(for: .tooMany(running: running))
    }

    private func talkingDown(
        named: String?,
        caller: CrewCaller,
        store: Store
    ) async -> Result<Session, CrewToolTrouble> {
        guard let named else { return .failure(.saidToNobody) }

        let crew: [Session]
        do {
            crew = try await store.crew(of: caller.session.id)
        } catch {
            return .failure(.unexplained(tool: CrewToolName.say, error.readableMessage))
        }

        switch CrewLookup.find(named, among: crew) {
        case .found(let member):
            return .success(member)
        case .unknown:
            return .failure(
                .unknownMember(tool: CrewToolName.say, given: named, known: crew.map(\.title))
            )
        case .ambiguous:
            return .failure(.ambiguousMember(tool: CrewToolName.say, given: named))
        }
    }
}

public struct AgentListTool: BridgeToolHandling {
    public init() {}

    public let roles: Set<BridgeRole> = [.parent]

    public let tool = BridgeTool(
        name: CrewToolName.list,
        description: """
            List the agents working in this workspace beside you: the ones started with \
            agent_start, what each is called, whether it is running, and what it is doing. Call it \
            before agent_say or agent_stop, because the name is how those two address an agent.

            Task subagents are not on this list and cannot be. Everything here is a chat of its \
            own that outlives the turn that started it, which is why there is something to name, \
            to talk to and to stop.

            If you started subagents, it lists yours. If you are yourself a subagent, it lists the \
            whole crew, so you can see who else is in this worktree. Everyone in the list shares \
            this branch and these files, so somebody named here as running is somebody who may be \
            editing what you are about to edit.

            It takes no arguments, it reads and changes nothing, and it says how many of the \
            three running slots are taken.
            """,
        inputSchema: BridgeTool.noArguments
    )

    public func call(
        _ request: MCPRequest,
        as identity: BridgeIdentity,
        store: Store
    ) async -> BridgeToolResult {
        let caller: CrewCaller
        switch await CrewCaller.resolve(identity, store: store, tool: CrewToolName.list) {
        case .failure(let trouble): return .failure(trouble.sentence)
        case .success(let resolved): caller = resolved
        }

        let crew: [Session]
        let orchestrator: Session?
        do {
            crew = try await store.crew(of: caller.crewAnchor)
            orchestrator = caller.isCrewMember
                ? try await store.session(id: caller.crewAnchor)
                : caller.session
        } catch {
            return .failure(
                CrewToolTrouble.unexplained(tool: CrewToolName.list, error.readableMessage).sentence
            )
        }

        let running = crew.filter(CrewCensus.isRunning).count

        var answer: [String: JSONValue] = [
            "you": .string(caller.session.title),
            "you_are": .string(caller.isCrewMember ? "subagent" : "the agent that started them"),
            "crew": .array(crew.map { member in
                .object([
                    "name": .string(member.title),
                    "running": .bool(CrewCensus.isRunning(member)),
                    "state": .string(member.state.rawValue),
                    "is_you": .bool(member.id == caller.session.id),
                ])
            }),
            "running": .integer(running),
            "running_limit": .integer(Crew.ceiling),
            "note": .string(Self.note(crew: crew, running: running, caller: caller)),
        ]

        if caller.isCrewMember, let orchestrator {
            answer["orchestrator"] = .string(orchestrator.title)
        }

        return .json(.object(answer))
    }

    private static func note(crew: [Session], running: Int, caller: CrewCaller) -> String {
        guard !crew.isEmpty else {
            return caller.isCrewMember
                ? "You are the only agent on this job. Anything you need goes up, with agent_say."
                : "You have started no subagents. agent_start is how one begins, and it shares "
                    + "this worktree and this branch with you."
        }

        let slots = Crew.ceiling - running
        let room = slots > 0
            ? "\(slots) of the \(Crew.ceiling) running slots are free."
            : "All \(Crew.ceiling) running slots are taken, so agent_start will be refused until "
                + "one of them stops."

        return caller.isCrewMember
            ? "Everyone here is editing the same files on the same branch as you. \(room) You can "
                + "only talk upwards: agent_say with no 'to' reaches the agent that started you."
            : "Everyone here is editing the same files on the same branch as you. \(room) Talk to "
                + "one with agent_say, and stop one with agent_stop."
                + tidying(crew: crew, running: running)
    }

    private static func tidying(crew: [Session], running: Int) -> String {
        let finished = crew.count - running
        guard finished > 0 else { return "" }

        let total = crew.count == 1 ? "1 subagent" : "\(crew.count) subagents"
        return " \(total): \(running) running, \(finished) finished. A finished one keeps its "
            + "name and its row in the sidebar until you say you are done with it. " + Crew.tidyHint
    }
}

public struct AgentStopTool: BridgeToolHandling {
    private let stop: CrewStopping

    public init(_ stop: @escaping CrewStopping) {
        self.stop = stop
    }

    public let roles: Set<BridgeRole> = [.parent]

    public let tool = BridgeTool(
        name: CrewToolName.stop,
        description: """
            Finish with a subagent you started with agent_start, by name. Call it when the agent \
            has done what you started it for, when what it was given is no longer wanted, or when \
            you need the slot, because three subagents may run in one workspace at once.

            'name' is required and is the name agent_list prints.

            It ends that agent if it is still running, takes its row out of the owner's sidebar, \
            and frees its name for another subagent to use. Nothing it did is undone: everything \
            it wrote in the worktree stays exactly as it left it, and its conversation stays in \
            Unified Dev for the owner to read.

            This is how you finish with an agent and not only how you interrupt one. A Task \
            subagent ends itself when your turn ends; one of these does not, so an agent you have \
            no more work for keeps its name and sits in the owner's sidebar until you say you are \
            done with it.

            Only the agent that started a subagent may stop it.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "name": .object([
                    "type": .string("string"),
                    "description": .string(
                        "Which of your subagents to stop, by the name agent_list prints."
                    ),
                ]),
            ]),
            "required": .array([.string("name")]),
        ])
    )

    public func call(
        _ request: MCPRequest,
        as identity: BridgeIdentity,
        store: Store
    ) async -> BridgeToolResult {
        guard let named = AgentStartTool.text(request.stringParam("name")) else {
            return .failure(CrewToolTrouble.noNameToStop.sentence)
        }

        let caller: CrewCaller
        switch await CrewCaller.resolve(identity, store: store, tool: CrewToolName.stop) {
        case .failure(let trouble): return .failure(trouble.sentence)
        case .success(let resolved): caller = resolved
        }

        guard !caller.isCrewMember else {
            return .failure(CrewToolTrouble.stoppingIsTheOrchestratorsCall.sentence)
        }

        let crew: [Session]
        do {
            crew = try await store.crew(of: caller.session.id)
        } catch {
            return .failure(
                CrewToolTrouble.unexplained(tool: CrewToolName.stop, error.readableMessage).sentence
            )
        }

        let member: Session
        switch CrewLookup.find(named, among: crew) {
        case .found(let found):
            member = found
        case .unknown:
            return .failure(
                CrewToolTrouble.unknownMember(
                    tool: CrewToolName.stop, given: named, known: crew.map(\.title)
                ).sentence
            )
        case .ambiguous:
            return .failure(
                CrewToolTrouble.ambiguousMember(tool: CrewToolName.stop, given: named).sentence
            )
        }

        switch await stop(member.title, caller.session.id, caller.workspaceID) {
        case .stopped(let sentence): return BridgeToolResult(text: sentence)
        case .refused(let refusal): return .failure(refusal)
        }
    }
}
