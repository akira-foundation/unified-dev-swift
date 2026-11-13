import Foundation
import Testing
@testable import Core

@Suite("What a Bitbucket read falls back on when the first answer is not enough")
struct BitbucketFallbackTests {
    private actor Calls {
        var seen: [[String]] = []
        func record(_ arguments: [String]) { seen.append(arguments) }
    }

    private static let signedIn = """
    {"hosts": [{"key": "api.bitbucket.org", "kind": "cloud"}],
     "contexts": [{"name": "work", "host": "api.bitbucket.org", "active": true}]}
    """

    private static let emptyPage = #"{"values": []}"#

    private func workspace(number: Int? = nil) -> Workspace {
        var workspace = Workspace(
            repoID: Repo(name: "aui", path: "/nowhere/aui").id,
            name: "upmerge", branch: "issue/10.2.x/upmerge", path: TestScratch.unique("bitbucket-fallback"),
            baseBranch: "release/10.2.x", createdAt: .distantPast
        )
        workspace.pullRequestNumber = number
        return workspace
    }

    private func read(
        _ workspace: Workspace,
        remote: String = "git@bitbucket.org:atlassian/aui.git",
        calls: Calls,
        answer: @escaping @Sendable ([String]) -> ShellResult
    ) async -> PullRequestReading? {
        await Forge.$remoteOverride.withValue({ _ in remote }) {
            await Bitbucket.$commandOverride.withValue({ arguments, _ in
                await calls.record(arguments)
                if arguments.starts(with: ["auth", "status"]) {
                    return ShellResult(status: 0, stdout: Self.signedIn, stderr: "")
                }
                return answer(arguments)
            }) {
                await Bitbucket.readingIfHosted(for: workspace, maxAge: .zero)
            }
        }
    }

    private func pullRequest(of reading: PullRequestReading?) -> PullRequest? {
        guard case .current(let found) = reading?.pullRequest else { return nil }
        return found
    }

    @Test("a GitHub workspace is left to GitHub, and bkt is never run")
    func gitHubIsNotRead() async {
        let calls = Calls()
        let reading = await read(workspace(), remote: "git@github.com:acme/widgets.git", calls: calls) { _ in
            ShellResult(status: 0, stdout: Self.emptyPage, stderr: "")
        }

        #expect(reading == nil)
        #expect(await calls.seen.isEmpty)
    }

    @Test("builds that cannot be read leave the pull request shown, with its checks unreadable")
    func unreadableBuilds() async throws {
        let reading = await read(workspace(), calls: Calls()) { arguments in
            if arguments[1].hasSuffix("/statuses") {
                return ShellResult(status: 1, stdout: "", stderr: "HTTP 403 Forbidden")
            }
            let page = "{\"values\": [\(BitbucketPullRequestTests.pullRequestJSON())]}"
            return ShellResult(status: 0, stdout: page, stderr: "")
        }

        let pullRequest = try #require(pullRequest(of: reading))
        #expect(pullRequest.number == 5486)
        #expect(pullRequest.checks == .unavailable)
        #expect(pullRequest.hasFixableCheckFailure == nil)
        #expect(reading?.checks == .unreadable)
    }

    @Test("with nothing on the branch, the number the workspace recorded is read")
    func readsRecordedNumber() async throws {
        let calls = Calls()
        let reading = await read(workspace(number: 5486), calls: calls) { arguments in
            if arguments[1].hasSuffix("/pullrequests/5486") {
                return ShellResult(status: 0, stdout: BitbucketPullRequestTests.pullRequestJSON(), stderr: "")
            }
            if arguments[1].hasSuffix("/statuses") {
                return ShellResult(status: 0, stdout: Self.emptyPage, stderr: "")
            }
            return ShellResult(status: 0, stdout: Self.emptyPage, stderr: "")
        }

        #expect(try #require(pullRequest(of: reading)).number == 5486)
        #expect(await calls.seen.contains { $0[1] == "/repositories/atlassian/aui/pullrequests/5486" })
    }

    @Test("a recorded number Bitbucket no longer knows reads as no pull request", arguments: [
        ShellResult(status: 1, stdout: "", stderr: "HTTP 404 Not Found"),
        ShellResult(status: 1, stdout: #"{"type": "error", "error": {"message": "404"}}"#, stderr: ""),
    ])
    func forgottenNumber(answer: ShellResult) async {
        let reading = await read(workspace(number: 9999), calls: Calls()) { arguments in
            arguments[1].hasSuffix("/pullrequests/9999") ? answer : ShellResult(status: 0, stdout: Self.emptyPage, stderr: "")
        }

        guard case .current(let found) = reading?.pullRequest else {
            Issue.record("expected an answer, got \(String(describing: reading?.pullRequest))")
            return
        }
        #expect(found == nil)
    }

    @Test("a head that is not a hash is never put in a path")
    func refusesOddHead() async throws {
        let calls = Calls()
        let odd = BitbucketPullRequestTests.pullRequestJSON(hash: "../../user")
        let reading = await read(workspace(), calls: calls) { _ in
            ShellResult(status: 0, stdout: "{\"values\": [\(odd)]}", stderr: "")
        }

        #expect(try #require(pullRequest(of: reading)).checks == PullRequest.Checks.none)
        #expect(await !calls.seen.contains { $0[1].hasSuffix("/statuses") })
    }
}
