import Foundation

public struct AgentAccountLiveness: Sendable {
    public enum CliReport: Sendable, Hashable {
        case claimsSession
        case claimsNoSession
        case unanswered
    }

    public static let arguments = ["auth", "status"]

    public static let timeout: Duration = .seconds(10)

    private let executable: String
    private let cwd: String
    private let environment: [String: String]?
    private let timeout: Duration
    private let makeProcess: @Sendable (AgentLaunch) -> any AgentProcessing

    public init(
        executable: String = AgentRunner.executable,
        cwd: String = AgentScratchDirectory.current(),
        environment: [String: String]? = nil,
        timeout: Duration = AgentAccountLiveness.timeout,
        makeProcess: @escaping @Sendable (AgentLaunch) -> any AgentProcessing = AgentRunner.spawn
    ) {
        self.executable = executable
        self.cwd = cwd
        self.environment = environment
        self.timeout = timeout
        self.makeProcess = makeProcess
    }

    public func report(for home: AgentAccountHome) async -> CliReport {
        guard home.provider == .claudeCode else { return .unanswered }
        await LoginShellPath.ready()
        let process = makeProcess(AgentLaunch(
            executable: executable,
            arguments: Self.arguments,
            cwd: cwd,
            environment: AgentAccountEnvironment.apply(home, to: environment ?? Shell.environment())
        ))
        let lines = process.lines
        process.closeStdin()

        let deadline = timeout
        let answer = await withTaskGroup(of: CliReport?.self) { group in
            group.addTask { await Self.firstReport(in: lines) }
            group.addTask {
                try? await Task.sleep(for: deadline)
                return nil
            }
            let first = await group.next()
            group.cancelAll()
            return first.flatMap { $0 }
        }
        process.terminate()
        return answer ?? .unanswered
    }

    static func report(in output: String) -> CliReport? {
        guard let loggedIn = JSONValue.parse(Data(output.utf8))?["loggedIn"]?.boolValue else { return nil }
        return loggedIn ? .claimsSession : .claimsNoSession
    }

    private static func firstReport(in lines: AsyncThrowingStream<String, Error>) async -> CliReport? {
        var output = ""
        do {
            for try await line in lines {
                output += line + "\n"
                if let report = report(in: output) { return report }
            }
        } catch {
            return nil
        }
        return nil
    }
}
