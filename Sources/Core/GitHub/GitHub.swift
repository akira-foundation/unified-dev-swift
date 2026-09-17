import Foundation

public struct CheckRun: Sendable, Hashable, Identifiable {
    public let name: String
    public let status: String
    public let conclusion: String?
    public let detailsURL: String?
    public let startedAt: Date?
    public let completedAt: Date?
    public let workflowName: String?
    private let required: Bool?

    public var id: String {
        [workflowName, name, detailsURL].compactMap { $0 }.joined(separator: ":")
    }

    public var isRequired: Bool { required ?? true }

    public init(
        name: String,
        status: String,
        conclusion: String? = nil,
        detailsURL: String? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        workflowName: String? = nil,
        isRequired: Bool? = nil
    ) {
        self.name = name
        self.status = status
        self.conclusion = conclusion
        self.detailsURL = detailsURL
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.workflowName = workflowName
        self.required = isRequired
    }
}

public enum GitHubAccess: Sendable, Equatable {
    case ready
    case notInstalled
    case signedOut
}

public struct GitHubError: Error, Sendable, CustomStringConvertible {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var description: String { message }
}

private struct PullRequestPayload: Decodable {
    let number: Int?
    let title: String?
    let url: String?
    let state: String?
    let isDraft: Bool?
    let mergeable: String?
    let mergeStateStatus: String?
    let reviewDecision: String?
    let headRefName: String?
    let statusCheckRollup: [CheckPayload]?
    let closedAt: String?
}

private struct HeadPayload: Decodable {
    let number: Int?
    let closedAt: String?
}

private struct CheckPayload: Decodable {
    let typeName: String?
    let name: String?
    let status: String?
    let conclusion: String?
    let detailsURL: String?
    let startedAt: String?
    let completedAt: String?
    let workflowName: String?
    let context: String?
    let state: String?
    let targetURL: String?
    let isRequired: Bool?
    let required: Bool?

    enum CodingKeys: String, CodingKey {
        case typeName = "__typename"
        case name, status, conclusion, startedAt, completedAt, workflowName, context, state
        case detailsURL = "detailsUrl"
        case targetURL = "targetUrl"
        case isRequired, required
    }
}

struct PullRequestSnapshot: Sendable {
    let pullRequest: PullRequest
    let runs: [CheckRun]
}

private actor GitHubCache {
    enum Lookup: Hashable, Sendable {
        case branch(String)
        case number(Int)
    }

    struct Key: Hashable, Sendable {
        let worktree: String
        let lookup: Lookup
        let repository: String?
    }

    struct Entry: Sendable {
        let snapshot: PullRequestSnapshot?
        let storedAt: ContinuousClock.Instant
    }

    private var entries: [Key: Entry] = [:]

    func value(for key: Key, maxAge: Duration) -> PullRequestSnapshot?? {
        guard maxAge > .zero, let entry = entries[key] else { return nil }
        guard entry.storedAt.duration(to: .now) <= maxAge else {
            entries[key] = nil
            return nil
        }
        return .some(entry.snapshot)
    }

    func store(_ snapshot: PullRequestSnapshot?, for key: Key) {
        entries[key] = Entry(snapshot: snapshot, storedAt: .now)
    }
}

private actor UnreadableChecks {
    private static let lifetime = Duration.seconds(600)
    private var recorded: [String: ContinuousClock.Instant] = [:]

    func contains(_ worktree: String) -> Bool {
        guard let at = recorded[worktree] else { return false }
        guard at.duration(to: .now) <= Self.lifetime else {
            recorded[worktree] = nil
            return false
        }
        return true
    }

    func record(_ worktree: String) {
        recorded[worktree] = .now
    }
}

public enum GitHub {
    public enum MergeMethod: String, Sendable, CaseIterable {
        case merge
        case squash
        case rebase
    }

    private static let cache = GitHubCache()
    private static let unreadableChecks = UnreadableChecks()
    private static let fieldList = [
        "number", "title", "url", "state", "isDraft", "mergeable",
        "mergeStateStatus", "reviewDecision", "headRefName", "statusCheckRollup",
        "closedAt",
    ]
    private static let fields = fieldList.joined(separator: ",")
    private static let fieldsWithoutChecks = fieldList.filter { $0 != "statusCheckRollup" }
        .joined(separator: ",")

    public static let checksUnavailableSummary = "Checks unavailable"

    public static func isAvailable() async -> Bool {
        await access() == .ready
    }

    public static func access() async -> GitHubAccess {
        guard Shell.which("gh") != nil else { return .notInstalled }
        guard let result = try? await Shell.run(
            "gh", ["auth", "status"], timeout: .seconds(20)
        ) else {
            return .signedOut
        }
        return result.ok ? .ready : .signedOut
    }

    public static func pullRequest(
        forBranch branch: String,
        worktree: String,
        maxAge: Duration = .zero
    ) async throws -> PullRequest? {
        try await snapshot(forBranch: branch, worktree: worktree, maxAge: maxAge)?.pullRequest
    }

    public static func decodePullRequest(from data: Data) throws -> PullRequest {
        try decodeSnapshot(from: data).pullRequest
    }

    public static func decodeChecks(from data: Data) throws -> [CheckRun] {
        try decodeSnapshot(from: data).runs
    }

    public static func rollup(_ runs: [CheckRun]) -> (PullRequest.Checks, String) {
        guard !runs.isEmpty else { return (.none, "No checks") }

        let failed = runs.filter(\.isFailure)
        let requiredFailures = failed.filter(\.isRequired)
        let optionalFailures = failed.filter { !$0.isRequired }
        let pending = runs.filter(\.isPending)

        if !requiredFailures.isEmpty {
            return (.failing, countSummary(requiredFailures.count, singular: "required check failed"))
        }
        if !pending.isEmpty {
            let running = pending.filter { CheckState($0) == .running }
            if !running.isEmpty {
                return (.pending, countSummary(running.count, singular: "check running"))
            }
            return (.pending, countSummary(pending.count, singular: "check queued"))
        }
        if !optionalFailures.isEmpty {
            return (.passing, countSummary(optionalFailures.count, singular: "optional check failed"))
        }
        return (.passing, countSummary(runs.count, singular: "check passed"))
    }

    public static func createPullRequest(
        worktree: String,
        base: String,
        title: String,
        body: String,
        draft: Bool
    ) async throws -> PullRequest {
        guard Git.isValidBranchName(base) else {
            throw GitHubError("refusing to open a pull request against '\(base)': not a valid branch name")
        }
        var arguments = ["pr", "create", "--base", base, "--title", title, "--body", body]
        if draft { arguments.append("--draft") }
        try await checkGH(arguments, worktree: worktree)

        let view = try await viewPullRequest([], worktree: worktree)
        guard view.result.ok else { throw shellError(arguments: view.arguments, result: view.result) }
        return try decodeSnapshot(
            from: Data(view.result.stdout.utf8), checksReadable: view.checksReadable
        ).pullRequest
    }

    public static func checkRunLog(
        _ target: CheckFailureHandoff.LogTarget,
        worktree: String,
        timeout: Duration = .seconds(90)
    ) async throws -> String {
        var selector = [target.runID]
        if let jobID = target.jobID { selector = ["--job", jobID] }

        let failed = try await run(
            "gh", ["run", "view"] + selector + ["--log-failed"], cwd: worktree, timeout: timeout
        )
        let trimmed = failed.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if failed.ok, !trimmed.isEmpty { return failed.stdout }

        let whole = try await run(
            "gh", ["run", "view"] + selector + ["--log"], cwd: worktree, timeout: timeout
        )
        guard whole.ok, !whole.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let reason = [failed.stderr, whole.stderr]
                .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            throw GitHubError(reason.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                ?? "gh returned no log for this check run")
        }
        return whole.stdout
    }

    public static func push(
        worktree: String,
        branch: String,
        setUpstream: Bool,
        timeout: Duration = .seconds(20)
    ) async throws {
        guard Git.isValidBranchName(branch) else {
            throw GitHubError("refusing to push to '\(branch)': not a valid branch name")
        }

        let context = try await Git.repositoryContext(in: worktree, branch: branch)
        guard let remote = context.publishRemote else {
            throw GitHubError("No publication remote is configured. For a pull request checkout, set branch.\(branch).pushRemote or remote.pushDefault before pushing directly.")
        }
        if setUpstream { try await Git.recordBase(context, for: branch, in: worktree) }
        var arguments = ["push"]
        if setUpstream { arguments.append("--set-upstream") }
        arguments += ["--", remote, "HEAD:refs/heads/\(context.publishBranch)"]

        let result = try await run("git", arguments, cwd: worktree, timeout: timeout)
        guard result.ok else {
            throw ShellError(
                command: "git " + arguments.joined(separator: " "),
                status: result.status,
                stderr: result.stderr.isEmpty ? result.stdout : result.stderr
            )
        }
    }

    public static func hasRemoteBranch(_ branch: String, worktree: String) async -> Bool {
        guard Git.isValidBranchName(branch) else { return false }
        guard let context = try? await Git.repositoryContext(in: worktree, branch: branch),
              let remote = context.publishRemote else { return false }
        guard let result = try? await run(
            "git", ["ls-remote", "--exit-code", "--heads", "--", remote, "refs/heads/\(context.publishBranch)"],
            cwd: worktree,
            timeout: .seconds(20)
        ) else { return false }
        return result.ok
    }

    public static func indicatesNoPullRequest(stderr: String) -> Bool {
        stderr.localizedCaseInsensitiveContains("no pull requests found")
            || stderr.localizedCaseInsensitiveContains("could not resolve to a pullrequest")
    }

    public static func indicatesDetachedHead(stderr: String) -> Bool {
        stderr.localizedCaseInsensitiveContains("not on any branch")
            || stderr.localizedCaseInsensitiveContains("could not determine current branch")
    }

    public static func indicatesUnreadableChecks(stderr: String) -> Bool {
        stderr.localizedCaseInsensitiveContains("resource not accessible")
            && stderr.localizedCaseInsensitiveContains("statusCheckRollup")
    }

    struct PullRequestView {
        let result: ShellResult
        let arguments: [String]
        let checksReadable: Bool
    }

    static func viewPullRequest(
        _ selector: [String], worktree: String, repositoryContext: GitRepositoryContext? = nil
    ) async throws -> PullRequestView {
        let knownUnreadable = await unreadableChecks.contains(worktree)
        let arguments = ["pr", "view"] + selector + ["--json", knownUnreadable ? fieldsWithoutChecks : fields]
        let result = try await run("gh", arguments, cwd: worktree, repositoryContext: repositoryContext)
        guard !knownUnreadable, !result.ok, indicatesUnreadableChecks(stderr: result.stderr) else {
            return PullRequestView(result: result, arguments: arguments, checksReadable: !knownUnreadable)
        }

        await unreadableChecks.record(worktree)
        let bare = ["pr", "view"] + selector + ["--json", fieldsWithoutChecks]
        let retried = try await run("gh", bare, cwd: worktree, repositoryContext: repositoryContext)
        return PullRequestView(result: retried, arguments: bare, checksReadable: false)
    }

    static func snapshot(
        forBranch branch: String,
        worktree: String,
        maxAge: Duration
    ) async throws -> PullRequestSnapshot? {
        guard Git.isValidBranchName(branch) else {
            throw GitHubError("refusing to look up '\(branch)': not a valid branch name")
        }

        try Task.checkCancellation()
        let context = try? await Git.repositoryContext(in: worktree, branch: branch)
        let key = GitHubCache.Key(
            worktree: worktree, lookup: .branch(branch),
            repository: [context?.baseRemoteURL, context?.publishRemoteURL].compactMap { $0 }.joined(separator: "\n")
        )
        if let cached = await cache.value(for: key, maxAge: maxAge) { return cached }

        let view = try await viewPullRequest([branch], worktree: worktree, repositoryContext: context)
        let result = view.result
        guard result.ok else {
            if indicatesNoPullRequest(stderr: result.stderr) {
                if let fallback = try await snapshotOfCheckedOutBranch(branch, worktree: worktree) {
                    await cache.store(fallback, for: key)
                    return fallback
                }
                await cache.store(nil, for: key)
                return nil
            }
            throw shellError(arguments: view.arguments, result: result)
        }

        let snapshot = try decodeSnapshot(from: Data(result.stdout.utf8), checksReadable: view.checksReadable)
        await cache.store(snapshot, for: key)
        return snapshot
    }

    static func snapshot(
        forNumber number: Int,
        worktree: String,
        maxAge: Duration
    ) async throws -> PullRequestSnapshot? {
        guard number > 0 else { return nil }
        try Task.checkCancellation()
        let context = try? await Git.repositoryContext(in: worktree)
        let key = GitHubCache.Key(worktree: worktree, lookup: .number(number), repository: context?.baseRemoteURL)
        if let cached = await cache.value(for: key, maxAge: maxAge) { return cached }
        let view = try await viewPullRequest([String(number)], worktree: worktree, repositoryContext: context)
        let result = view.result
        guard result.ok else {
            if indicatesNoPullRequest(stderr: result.stderr) {
                await cache.store(nil, for: key)
                return nil
            }
            throw shellError(arguments: view.arguments, result: result)
        }
        let snapshot = try decodeSnapshot(from: Data(result.stdout.utf8), checksReadable: view.checksReadable)
        await cache.store(snapshot, for: key)
        return snapshot
    }

    static func pullRequestsWithHead(
        _ branch: String, worktree: String
    ) async throws -> [PullRequestHeadMatch] {
        guard Git.isValidBranchName(branch) else { return [] }
        let result = try await run(
            "gh",
            [
                "pr", "list", "--head", branch, "--state", "all", "--limit", "20",
                "--json", "number,closedAt",
            ],
            cwd: worktree,
            timeout: .seconds(20)
        )
        guard result.ok else { throw shellError(arguments: ["pr", "list", "--head", branch], result: result) }
        let payloads = try JSONDecoder().decode([HeadPayload].self, from: Data(result.stdout.utf8))

        return payloads
            .compactMap { payload in
                guard let number = payload.number, number > 0 else { return nil }
                return PullRequestHeadMatch(number: number, closedAt: parseDate(payload.closedAt))
            }
            .sorted { $0.number > $1.number }
    }

    private static func snapshotOfCheckedOutBranch(
        _ branch: String, worktree: String
    ) async throws -> PullRequestSnapshot? {
        let view = try await viewPullRequest([], worktree: worktree)
        let result = view.result
        guard result.ok else {
            if indicatesNoPullRequest(stderr: result.stderr) || indicatesDetachedHead(stderr: result.stderr) {
                return nil
            }
            throw shellError(arguments: view.arguments, result: result)
        }

        let snapshot = try decodeSnapshot(from: Data(result.stdout.utf8), checksReadable: view.checksReadable)
        guard snapshot.pullRequest.branch == branch else { return nil }
        return snapshot
    }

    private static func decodeSnapshot(from data: Data, checksReadable: Bool = true) throws -> PullRequestSnapshot {
        let payload: PullRequestPayload
        do {
            payload = try JSONDecoder().decode(PullRequestPayload.self, from: data)
        } catch {
            let raw = String(decoding: data.suffix(1_024), as: UTF8.self)
            throw GitHubError("Could not decode gh JSON: \(error). Raw JSON tail: \(raw)")
        }

        let runs = checksReadable ? (payload.statusCheckRollup ?? []).map(normalize) : []
        let (checks, summary) = checksReadable
            ? rollup(runs) : (.unavailable, checksUnavailableSummary)
        return PullRequestSnapshot(
            pullRequest: PullRequest(
                number: payload.number ?? 0,
                title: payload.title ?? "",
                url: payload.url ?? "",
                state: payload.state ?? "UNKNOWN",
                isDraft: payload.isDraft ?? false,
                mergeable: payload.mergeable ?? payload.mergeStateStatus,
                checks: checks,
                checksSummary: summary,
                reviewDecision: payload.reviewDecision,
                branch: payload.headRefName ?? "",
                closedAt: parseDate(payload.closedAt)
            ),
            runs: runs
        )
    }

    private static func normalize(_ payload: CheckPayload) -> CheckRun {
        if payload.typeName == "StatusContext" {
            let state = payload.state ?? "PENDING"
            return CheckRun(
                name: payload.context ?? "Status",
                status: state == "PENDING" || state == "EXPECTED" ? "PENDING" : "COMPLETED",
                conclusion: state,
                detailsURL: payload.targetURL,
                isRequired: payload.isRequired ?? payload.required
            )
        }

        return CheckRun(
            name: payload.name ?? payload.context ?? "Check",
            status: payload.status ?? "PENDING",
            conclusion: payload.conclusion,
            detailsURL: payload.detailsURL ?? payload.targetURL,
            startedAt: parseDate(payload.startedAt),
            completedAt: parseDate(payload.completedAt),
            workflowName: payload.workflowName,
            isRequired: payload.isRequired ?? payload.required
        )
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty, !value.hasPrefix("0001-01-01") else { return nil }
        return (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value))
            ?? (try? Date.ISO8601FormatStyle(includingFractionalSeconds: false).parse(value))
    }

    private static func countSummary(_ count: Int, singular: String) -> String {
        count == 1 ? "1 \(singular)" : "\(count) \(singular.replacingOccurrences(of: "check ", with: "checks "))"
    }

    @discardableResult
    private static func checkGH(_ arguments: [String], worktree: String) async throws -> ShellResult {
        let result = try await run(
            "gh", arguments, cwd: worktree, timeout: .seconds(20)
        )
        guard result.ok else { throw shellError(arguments: arguments, result: result) }
        return result
    }

    private static func shellError(arguments: [String], result: ShellResult) -> ShellError {
        ShellError(
            command: "gh " + arguments.joined(separator: " "),
            status: result.status,
            stderr: result.stderr.isEmpty ? result.stdout : result.stderr
        )
    }
}

private extension CheckRun {
    var isPending: Bool {
        let normalizedStatus = status.uppercased()
        return normalizedStatus != "COMPLETED" && normalizedStatus != "SUCCESS" && normalizedStatus != "FAILURE" && normalizedStatus != "ERROR"
    }

    var isFailure: Bool {
        guard let conclusion else { return false }
        return [
            "FAILURE", "ERROR", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED",
            "STARTUP_FAILURE", "STALE",
        ].contains(conclusion.uppercased())
    }
}

public struct GitHubOwner: Sendable, Hashable, Identifiable {
    public enum Kind: Sendable, Hashable {
        case user
        case organization
    }

    public let login: String
    public let kind: Kind

    public var id: String { login }

    public init(login: String, kind: Kind) {
        self.login = login
        self.kind = kind
    }
}

private struct LoginPayload: Decodable {
    let login: String
}

public extension GitHub {
    static func owners() async throws -> [GitHubOwner] {
        let me = try await api(["user"], timeout: .seconds(20))
        let user = try JSONDecoder().decode(LoginPayload.self, from: Data(me.utf8))

        var owners = [GitHubOwner(login: user.login, kind: .user)]
        if let orgs = try? await api(["user/orgs", "--paginate"], timeout: .seconds(20)),
           let decoded = try? JSONDecoder().decode([LoginPayload].self, from: Data(orgs.utf8)) {
            owners += decoded.map { GitHubOwner(login: $0.login, kind: .organization) }
        }
        return owners
    }

    static func repositoryAvailability(owner: String, name: String) async -> NameAvailability {
        guard GitHubRepositoryName.isValid(name), isPlausibleLogin(owner) else {
            return .unknown("Unified Dev did not check that name.")
        }
        guard let result = try? await run(
            "gh", ["api", "--silent", "repos/\(owner)/\(name)"], timeout: .seconds(15)
        ) else {
            return .unknown("Unified Dev could not reach GitHub to check that name.")
        }
        if result.ok { return .taken }

        let output = result.stderr + result.stdout
        if output.contains("HTTP 404") || output.localizedCaseInsensitiveContains("not found") {
            return .available
        }
        return .unknown("Unified Dev could not check that name with GitHub.")
    }

    static func createRepository(
        owner: String, name: String, isPrivate: Bool
    ) async throws -> String {
        if let problem = GitHubRepositoryName.problem(with: name) {
            throw GitHubError(problem.sentence)
        }
        guard isPlausibleLogin(owner) else {
            throw GitHubError("'\(owner)' is not a GitHub account name.")
        }

        let arguments = [
            "repo", "create", "\(owner)/\(name)", isPrivate ? "--private" : "--public",
        ]
        let result = try await run("gh", arguments, timeout: .seconds(60))
        guard result.ok else {
            throw ShellError(
                command: "gh " + arguments.joined(separator: " "),
                status: result.status,
                stderr: result.stderr.isEmpty ? result.stdout : result.stderr
            )
        }
        return await remoteURL(owner: owner, name: name)
    }

    static func remoteURL(owner: String, name: String) async -> String {
        let configured = try? await run(
            "gh", ["config", "get", "git_protocol"], timeout: .seconds(10)
        )
        let usesSSH = (configured?.ok ?? false) && configured?.trimmed == "ssh"
        return usesSSH
            ? "git@github.com:\(owner)/\(name).git"
            : "https://github.com/\(owner)/\(name).git"
    }

    static func repositoryPage(owner: String, name: String) -> String {
        "https://github.com/\(owner)/\(name)"
    }

    static func isPlausibleLogin(_ login: String) -> Bool {
        guard !login.isEmpty, login.count <= 39, !login.hasPrefix("-"), !login.hasSuffix("-") else {
            return false
        }
        return login.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
    }

    private static func api(_ path: [String], timeout: Duration) async throws -> String {
        let arguments = ["api"] + path
        let result = try await run("gh", arguments, timeout: timeout)
        guard result.ok else {
            throw ShellError(
                command: "gh " + arguments.joined(separator: " "),
                status: result.status,
                stderr: result.stderr.isEmpty ? result.stdout : result.stderr
            )
        }
        return result.stdout
    }
}
