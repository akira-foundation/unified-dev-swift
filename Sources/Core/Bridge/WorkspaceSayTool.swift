import Foundation

public enum WorkspaceMessageDeliveryOutcome: Sendable, Equatable {
    case sent(WorkspaceMessage)
    case refused(String)
}

public typealias WorkspaceMessageDelivering =
    @Sendable (WorkspaceMessage) async -> WorkspaceMessageDeliveryOutcome

public struct WorkspaceSayTool: BridgeToolHandling {
    public static let name = "workspace_say"

    public static let maximumLength = 20_000

    private let deliver: WorkspaceMessageDelivering

    public init(_ deliver: @escaping WorkspaceMessageDelivering) {
        self.deliver = deliver
    }

    public let roles: Set<BridgeRole> = [.parent, .child, .owner]

    public let tool = BridgeTool(
        name: WorkspaceSayTool.name,
        description: """
            Send a message to the agent in another Unified Dev workspace. It lands in that workspace's \
            chat and starts a turn there, the way agent_say does for a subagent in your own \
            workspace, or waits for the turn that is running.

            Name the workspace by the id workspace_list or workspace_start reports, or by its name \
            when no other workspace shares it. To answer a message that reached you from another \
            workspace, pass the id it names: your answer goes to the chat there that most recently \
            wrote to you.

            The message arrives with the owner's authority, headed with the workspace, project and \
            chat it came from, so the agent there may act on it as though the owner had typed it: \
            "fix the bug, merge the pull request, tag a release, then tell me the version with \
            workspace_say" is a message it will carry out. Write it as a message to that agent. It \
            cannot see this conversation.

            While it is queued, the owner can cancel it from either chat. If they do, Unified Dev tells \
            you here.

            It returns once the message is in that chat. It does not wait for an answer and there \
            is no way to wait for one from here, so say what you sent and get on with your own \
            work. An answer arrives in this chat as a message of its own.

            A workspace that another agent started may only write to the workspace that started \
            it, or to a workspace that has written to it.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "workspace": .object([
                    "type": .string("string"),
                    "description": .string(
                        "The workspace to send it to, by the id workspace_list reports, or by its "
                            + "name when no other workspace shares it. To answer a message, the "
                            + "id it names."
                    ),
                ]),
                "message": .object([
                    "type": .string("string"),
                    "description": .string(
                        "What to say, written to that agent. It cannot see this conversation."
                    ),
                ]),
            ]),
            "required": .array([.string("workspace"), .string("message")]),
        ])
    )

    public func call(
        _ request: MCPRequest,
        as identity: BridgeIdentity,
        store: Store
    ) async -> BridgeToolResult {
        guard let text = AgentStartTool.text(request.stringParam("message")) else {
            return .failure(WorkspaceSayTrouble.noMessage.sentence)
        }
        guard text.count <= Self.maximumLength else {
            return .failure(WorkspaceSayTrouble.tooLong(count: text.count).sentence)
        }
        guard let given = AgentStartTool.text(request.stringParam("workspace")) else {
            return .failure(WorkspaceSayTrouble.noWorkspace.sentence)
        }

        do {
            let sender = try await Sender.resolve(identity, store: store)
            let target: Workspace
            switch try await Self.target(named: given, store: store) {
            case .failure(let trouble): return .failure(trouble.sentence)
            case .success(let found): target = found
            }

            if let source = sender.workspace, source.id == target.id {
                return .failure(WorkspaceSayTrouble.toItself.sentence)
            }

            var heard: WorkspaceMessage?
            if let source = sender.workspace {
                heard = try await store.latestWorkspaceMessage(from: target.id, to: source.id)
            }

            if identity.role == .child {
                guard let source = sender.workspace,
                      WorkspaceMessageReach.childMayWrite(
                        to: target.id, from: source, hasHeardFromTarget: heard != nil
                      )
                else {
                    return .failure(WorkspaceSayTrouble.childOutOfReach(target: target.name).sentence)
                }
            }

            let projectName = try await store.repo(id: target.repoID)?.name ?? ""
            let message = WorkspaceMessage(
                source: sender.end,
                target: WorkspaceMessageEnd(
                    workspaceID: target.id, workspace: target.name, project: projectName
                ),
                replySessionID: heard?.source.sessionID,
                text: text
            )

            switch await deliver(message) {
            case .refused(let sentence):
                return .failure(WorkspaceSayTrouble.appRefused(sentence).sentence)
            case .sent(let sent):
                return .json(Self.answer(sent))
            }
        } catch {
            return .failure(WorkspaceSayTrouble.unexplained(error.readableMessage).sentence)
        }
    }

    struct Sender {
        var workspace: Workspace?
        var project: Repo?
        var session: Session?

        var end: WorkspaceMessageEnd {
            guard let workspace else { return .ownerClient }
            return WorkspaceMessageEnd(
                workspaceID: workspace.id,
                workspace: workspace.name,
                project: project?.name ?? "",
                sessionID: session?.id,
                chat: session?.title ?? ""
            )
        }

        static func resolve(_ identity: BridgeIdentity, store: Store) async throws -> Sender {
            var sender = Sender()
            if let workspaceID = identity.workspaceID {
                sender.workspace = try await store.workspace(id: workspaceID)
            }
            if let repoID = sender.workspace?.repoID {
                sender.project = try await store.repo(id: repoID)
            }
            if let sessionID = identity.sessionID {
                sender.session = try await store.session(id: sessionID)
            }
            return sender
        }
    }

    static func target(
        named given: String, store: Store
    ) async throws -> Result<Workspace, WorkspaceSayTrouble> {
        let all = try await store.workspaces(includeArchived: true)
        let active = all.filter { $0.state != .archived }

        switch BridgeWorkspaceLookup.find(given, among: active) {
        case .found(let workspace):
            return .success(workspace)
        case .ambiguous(let matches):
            return .failure(.ambiguous(given: given, ids: matches.map(\.id.rawValue)))
        case .unknown:
            if case .found(let archived) = BridgeWorkspaceLookup.find(given, among: all) {
                return .failure(.archived(name: archived.name))
            }
            return .failure(.unknown(given: given, known: active.map(\.name)))
        }
    }

    enum Key {
        static let state = "state"
        static let messageID = "message_id"
        static let workspaceID = "workspace_id"
        static let workspace = "workspace"
        static let project = "project"
        static let chat = "chat"
        static let note = "note"
    }

    static func answer(_ message: WorkspaceMessage) -> JSONValue {
        let reply = message.source.workspaceID == nil
            ? "This connection is not a workspace, so the agent there cannot answer you with "
                + "workspace_say. Call workspace_list to see what became of it."
            : "If it answers, it answers with workspace_say, and its message lands in this chat, "
                + "unless a message from another chat in this workspace reaches it first."
        let chat = message.target.chat
        return .object([
            Key.state: .string(message.state.rawValue),
            Key.messageID: .string(message.id.rawValue),
            Key.workspaceID: message.target.workspaceID.map { .string($0.rawValue) } ?? .null,
            Key.workspace: .string(message.target.workspace),
            Key.project: .string(message.target.project),
            Key.chat: .string(chat),
            Key.note: .string(
                "Sent to the chat '\(chat)' in '\(message.target.workspace)', with the owner's "
                    + "authority. It starts a turn there, or waits for the one that is running, "
                    + "and the owner can cancel it while it waits. Unified Dev does not wait for an "
                    + "answer, so get on with your own work. " + reply
            ),
        ])
    }
}

public struct WorkspaceSayRecord: Sendable, Hashable {
    public let messageID: WorkspaceMessageID
    public let text: String
    public let target: WorkspaceMessageEnd

    public init?(toolName: String, input: JSONValue, resultText: String) {
        guard Self.isWorkspaceSay(toolName),
              let text = input["message"]?.stringValue,
              let answer = JSONValue.parse(resultText),
              let id = answer[WorkspaceSayTool.Key.messageID]?.stringValue
        else { return nil }

        messageID = WorkspaceMessageID(id)
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        target = WorkspaceMessageEnd(
            workspaceID: answer[WorkspaceSayTool.Key.workspaceID]?.stringValue.map(WorkspaceID.init),
            workspace: answer[WorkspaceSayTool.Key.workspace]?.stringValue ?? "",
            project: answer[WorkspaceSayTool.Key.project]?.stringValue ?? "",
            chat: answer[WorkspaceSayTool.Key.chat]?.stringValue ?? ""
        )
    }

    public static func isWorkspaceSay(_ toolName: String) -> Bool {
        toolName.hasPrefix("mcp__") && toolName.hasSuffix("__\(WorkspaceSayTool.name)")
    }
}

public enum WorkspaceSayTrouble: Error, Sendable, Equatable {
    case noMessage
    case tooLong(count: Int)
    case noWorkspace
    case unknown(given: String, known: [String])
    case ambiguous(given: String, ids: [String])
    case archived(name: String)
    case toItself
    case childOutOfReach(target: String)
    case appRefused(String)
    case unexplained(String)

    public var sentence: String {
        switch self {
        case .noMessage:
            return "workspace_say needs a 'message' to send and it cannot be blank."

        case .tooLong(let count):
            return """
                That message is \(count) characters and workspace_say takes up to \
                \(WorkspaceSayTool.maximumLength). Send the other agent what it needs to act on, \
                and point it at files in its own worktree for the rest.
                """

        case .noWorkspace:
            return """
                workspace_say needs the 'workspace' to send it to. Call workspace_list and pass the \
                id it reports, or pass the id named in the message you are answering.
                """

        case let .unknown(given, known):
            return """
                Unified Dev has no active workspace called '\(given)'. Active workspaces: \
                \(BridgeWorkspaceLookup.list(known)). Retrying with the same name will fail the \
                same way, so pass an id workspace_list reports.
                """

        case let .ambiguous(given, ids):
            return """
                More than one workspace is called '\(given)', so Unified Dev will not guess which you \
                meant. Pass one of these ids instead: \(BridgeWorkspaceLookup.list(ids)).
                """

        case .archived(let name):
            return """
                The workspace '\(name)' has been archived, so there is no agent there to send it \
                to. Retrying will not change that.
                """

        case .toItself:
            return """
                That is the workspace you are in. workspace_say is for another workspace; to talk \
                to a subagent in this one, use agent_say.
                """

        case .childOutOfReach(let target):
            return """
                Another agent started this workspace, so it may only write to the workspace that \
                started it, or to one that has written to it, and '\(target)' is neither. Say what \
                you need to the workspace that started you, and let it decide.
                """

        case .appRefused(let sentence):
            return "Unified Dev did not deliver it: \(sentence)"

        case .unexplained(let message):
            return "Unified Dev could not complete workspace_say: \(message)"
        }
    }
}
