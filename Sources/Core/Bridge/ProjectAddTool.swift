import Foundation

public struct ProjectAddTool: BridgeToolHandling {
    public init() {}

    public let roles: Set<BridgeRole> = [.owner]

    public let tool = BridgeTool(
        name: "project_add",
        description: """
            Register a git repository that already exists as a project in Unified Dev, so workspaces \
            can be started in it. Takes the absolute path of the repository's folder.

            It only registers. It will not create a repository, and a folder that is not one \
            already is refused: do not run git init to make the call succeed, because whether a \
            folder should be a repository is the owner's decision. Adding a folder inside an \
            existing repository registers that repository, not the folder.

            Adding a project Unified Dev already has is not an error and changes nothing. This does not \
            copy, move or write anything inside the repository.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object([
                    "type": .string("string"),
                    "description": .string(
                        "Absolute path of the git repository's folder, starting at / or ~."
                    ),
                ]),
            ]),
            "required": .array([.string("path")]),
        ])
    )

    public func call(
        _ request: MCPRequest,
        as identity: BridgeIdentity,
        store: Store
    ) async -> BridgeToolResult {
        guard let path = request.stringParam("path")?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty
        else {
            return .failure("project_add needs the path of the git repository to register.")
        }

        let root: String
        switch await FolderVerdict.of(RepositoryStarter.inspect(path)) {
        case .alreadyRepository(let resolved):
            root = resolved
        case .refuse(let refusal):
            return .failure(refusal.agentSentence)
        case .offer:
            return .failure(FolderRefusal.notARepositoryForAgent(path: path))
        }

        do {
            let known = try await store.repo(path: root) != nil

            let project = try await WorkspaceManager(store: store).addRepository(at: root)
            return .json(.object([
                "id": .string(project.id.rawValue),
                "name": .string(project.name),
                "path": .string(project.path),
                "default_branch": .string(project.defaultBranch),
                "state": .string(known ? "already_a_project" : "added"),
                "note": .string(
                    known
                        ? "Unified Dev already had this repository as a project. Nothing changed."
                        : "It is in Unified Dev's sidebar now. Start work in it with workspace_start."
                ),
            ]))
        } catch {
            return .failure("Unified Dev could not add that project: \(error.readableMessage)")
        }
    }
}
