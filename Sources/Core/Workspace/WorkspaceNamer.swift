import Foundation

public struct WorkspaceNamerLaunch: Sendable, Hashable {
    public let executable: String
    public let arguments: [String]
    public let stdin: String
    public let cwd: String

    public init(executable: String, arguments: [String], stdin: String, cwd: String) {
        self.executable = executable
        self.arguments = arguments
        self.stdin = stdin
        self.cwd = cwd
    }
}

public struct WorkspaceNamer: Sendable {
    public typealias Run = @Sendable (WorkspaceNamerLaunch) async throws -> Data

    public static let executable = "claude"

    public static let model = "haiku"

    public static let systemPrompt = """
    You name coding tasks for a list of workspaces. Answer at once, through the structured \
    output, with no commentary before or after it.
    """

    public static let jsonSchema = """
    {"type":"object","properties":{"name":{"type":"string"},"branch":{"type":"string"}},\
    "required":["name","branch"],"additionalProperties":false}
    """

    public static let timeout = Duration.seconds(60)

    public static let taskLimit = 4_000

    private let run: Run

    public init(run: @escaping Run = WorkspaceNamer.shell) {
        self.run = run
    }

    public static let shell: Run = { launch in
        let result = try await Shell.run(
            launch.executable,
            launch.arguments,
            cwd: launch.cwd,
            stdin: launch.stdin,
            timeout: timeout
        )
        guard result.ok else {
            throw ShellError(
                command: launch.executable,
                status: result.status,
                stderr: result.stderr.isEmpty ? result.stdout : result.stderr
            )
        }
        return Data(result.stdout.utf8)
    }

    public static var isAvailable: Bool {
        Shell.which(executable) != nil
    }

    public static func argv(model: String = WorkspaceNamer.model) -> [String] {
        [
            "-p",
            "--model", ModelAlias.cliValue(for: model),
            "--effort", "low",
            "--output-format", "json",
            "--json-schema", jsonSchema,
            "--system-prompt", systemPrompt,
            "--tools", "",
            "--disable-slash-commands",
            "--strict-mcp-config",
            "--no-session-persistence",
            "--safe-mode",
        ]
    }

    public static var scratchDirectory: String { AgentScratchDirectory.current() }

    public static func launch(prompt: String, model: String = WorkspaceNamer.model) -> WorkspaceNamerLaunch {
        WorkspaceNamerLaunch(
            executable: executable,
            arguments: argv(model: model),
            stdin: prompt,
            cwd: scratchDirectory
        )
    }

    public static func prompt(
        task: String,
        project: String,
        template: String = PromptRegistry.definition(for: .nameWorkspace).defaultTemplate
    ) -> String {
        let trimmed = task.trimmingCharacters(in: .whitespacesAndNewlines)
        let capped = trimmed.count > taskLimit ? String(trimmed.prefix(taskLimit)) : trimmed

        return PromptTemplate.render(template, values: [
            PromptRegistry.NameWorkspace.task: capped,
            PromptRegistry.NameWorkspace.project: project,
        ]).text
    }

    public func suggest(
        task: String,
        project: String,
        template: String,
        branchPrefix: String? = nil
    ) async -> WorkspaceNameSuggestion? {
        let rendered = Self.prompt(task: task, project: project, template: template)
        guard !rendered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        guard let output = try? await run(Self.launch(prompt: rendered)) else { return nil }
        guard let decoded = WorkspaceNaming.decode(cliOutput: output) else { return nil }

        return WorkspaceNaming.suggestion(
            name: decoded.name,
            branch: decoded.branch,
            branchPrefix: branchPrefix
        )
    }
}
