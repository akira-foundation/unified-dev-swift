import Foundation
import Testing
@testable import Core

private actor Call {
    private(set) var arguments: [String] = []
    private(set) var bodyRead: String?
    private(set) var count = 0

    func saw(_ arguments: [String]) {
        self.arguments = arguments
        count += 1
        guard let index = arguments.firstIndex(of: "--body-file"), index + 1 < arguments.count else {
            return
        }
        bodyRead = try? String(contentsOfFile: arguments[index + 1], encoding: .utf8)
    }

    func bodyFile() -> String? {
        guard let index = arguments.firstIndex(of: "--body-file"), index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }
}

@Suite("Opening an issue through gh")
struct GitHubIssueTests {
    private static let filed = "https://github.com/akira-foundation/unified-dev-swift/issues/412\n"

    private func answering(
        _ result: @escaping @Sendable ([String]) -> ShellResult,
        _ call: Call = Call(),
        images: [String] = [],
        run: Bool = true
    ) async -> (Result<FiledIssue, IssueFailure>, Call) {
        let outcome = await GitHub.$commandOverride.withValue({ arguments, _ in
            await call.saw(arguments)
            return result(arguments)
        }) {
            await GitHub.createIssue(
                slug: "akira-foundation/unified-dev-swift",
                title: "Feedback: the sidebar loses its selection",
                body: "a body\nwith lines and a # heading",
                labels: ["bug"],
                images: images
            )
        }
        return (outcome, call)
    }

    @Test("the call names the repository, the title, the labels, a body file and each image")
    func theArgumentsAreRight() async {
        let (outcome, call) = await answering(
            { _ in ShellResult(status: 0, stdout: Self.filed, stderr: "") },
            images: ["/tmp/one.png", "/tmp/two.png"]
        )

        guard case .success(let issue) = outcome else {
            Issue.record("the issue was not created")
            return
        }
        #expect(issue.number == 412)
        #expect(issue.url.absoluteString.hasSuffix("/issues/412"))
        #expect(issue.attachments == .attached(2))

        let seen = await call.arguments
        #expect(seen.prefix(2) == ["issue", "create"])
        #expect(seen.contains("--repo"))
        #expect(seen.contains("akira-foundation/unified-dev-swift"))
        #expect(seen.contains("--title"))
        #expect(seen.contains("Feedback: the sidebar loses its selection"))
        #expect(seen.contains("--label"))
        #expect(seen.contains("bug"))
        #expect(seen.contains("--body-file"))
        #expect(!seen.contains("--body"))
        #expect(seen.filter { $0 == "--attach" }.count == 2)
        #expect(seen.contains("/tmp/one.png"))
        #expect(seen.contains("/tmp/two.png"))
    }

    @Test("a report with no images asks gh to attach nothing")
    func noImagesNoAttach() async {
        let (outcome, call) = await answering(
            { _ in ShellResult(status: 0, stdout: Self.filed, stderr: "") }
        )

        guard case .success(let issue) = outcome else {
            Issue.record("the issue was not created")
            return
        }
        #expect(issue.attachments == .none)
        #expect(!(await call.arguments.contains("--attach")))
    }

    @Test("the body reaches gh as a file, with every character of it")
    func theBodyIsWrittenToAFile() async {
        let (_, call) = await answering(
            { _ in ShellResult(status: 0, stdout: Self.filed, stderr: "") }
        )

        #expect(await call.bodyRead == "a body\nwith lines and a # heading")
    }

    @Test("the temporary body file does not survive the call")
    func theFileIsCleanedUp() async throws {
        let (_, call) = await answering(
            { _ in ShellResult(status: 0, stdout: Self.filed, stderr: "") }
        )
        let written = try #require(await call.bodyFile())

        #expect(!FileManager.default.fileExists(atPath: written))
    }

    @Test("a gh that says no comes back as a failure with what it said")
    func aRefusalIsAFailure() async {
        let (outcome, _) = await answering(
            { _ in ShellResult(status: 1, stdout: "", stderr: "gh: Not Found (HTTP 404)") }
        )

        guard case .failure(.refused(let said)) = outcome else {
            Issue.record("a refusal was read as a success")
            return
        }
        #expect(said.contains("404"))
    }

    @Test("an answer that is not an issue link is a failure rather than issue zero")
    func aStrangeAnswerIsAFailure() async {
        for said in ["", "Creating issue in akira-foundation/unified-dev-swift\n", "412\n"] {
            let (outcome, _) = await answering(
                { _ in ShellResult(status: 0, stdout: said, stderr: "") }
            )

            guard case .failure = outcome else {
                Issue.record("'\(said)' was read as a filed issue")
                return
            }
        }
    }

    @Test("a gh too old to attach files opens the issue anyway and says they did not go")
    func anOldGhFilesTheTextAlone() async {
        let call = Call()
        let (outcome, _) = await answering(
            { arguments in
                guard arguments.contains("--attach") else {
                    return ShellResult(status: 0, stdout: Self.filed, stderr: "")
                }
                return ShellResult(status: 1, stdout: "", stderr: "unknown flag: --attach")
            },
            call,
            images: ["/tmp/one.png"]
        )

        guard case .success(let issue) = outcome else {
            Issue.record("the retry without the images did not file the issue")
            return
        }
        #expect(issue.number == 412)
        #expect(issue.attachments == .notAttached(1))
        #expect(await call.count == 2)
        #expect(!(await call.arguments.contains("--attach")))
    }

    @Test("an upload that fails halfway keeps the issue and says the images need carrying over")
    func apartialUploadIsStillAnIssue() async {
        let (outcome, call) = await answering(
            { _ in
                ShellResult(
                    status: 1, stdout: Self.filed,
                    stderr: "failed to upload two.png: HTTP 502"
                )
            },
            images: ["/tmp/one.png", "/tmp/two.png"]
        )

        guard case .success(let issue) = outcome else {
            Issue.record("a part-uploaded issue was read as no issue at all")
            return
        }
        #expect(issue.number == 412)
        #expect(issue.attachments == .partly(2))
        #expect(await call.count == 1)
    }

    @Test("a failure that has nothing to do with attaching is not retried")
    func otherFailuresAreNotRetried() async {
        let (outcome, call) = await answering(
            { _ in ShellResult(status: 1, stdout: "", stderr: "gh: Not Found (HTTP 404)") },
            images: ["/tmp/one.png"]
        )

        #expect((try? outcome.get()) == nil)
        #expect(await call.count == 1)
    }

    @Test("a link that is not an issue of the repository asked for is not read as one")
    func onlyIssueLinksCount() {
        #expect(GitHub.issue(in: "https://github.com/a/b/pull/412", of: "a/b")?.number == nil)
        #expect(GitHub.issue(in: "https://github.com/a/b/issues", of: "a/b")?.number == nil)
        #expect(GitHub.issue(in: "https://github.com/a/b/issues/0", of: "a/b")?.number == nil)
        #expect(GitHub.issue(in: "http://github.com/a/b/issues/412", of: "a/b")?.number == nil)
        #expect(GitHub.issue(in: "https://github.com/c/d/issues/412", of: "a/b")?.number == nil)
        #expect(GitHub.issue(in: "https://github.com/a/b/issues/412", of: "a/b")?.number == 412)
    }

    @Test("the issue link is read from the last line, after whatever gh printed first")
    func theLinkIsTheLastLine() {
        let said = "Creating issue in a/b\n\nhttps://github.com/a/b/issues/7\n"

        #expect(GitHub.issue(in: said, of: "a/b")?.number == 7)
    }

    @Test("a gh that never answers is not read as a refusal, because the issue may exist")
    func aTimeoutIsNotARefusal() async {
        let outcome = await GitHub.$commandOverride.withValue({ _, _ in
            throw ShellError(command: "gh issue create", status: 15, stderr: "timed out")
        }) {
            await GitHub.createIssue(slug: "a/b", title: "t", body: "b", labels: [])
        }

        guard case .failure(.unanswered(let said)) = outcome else {
            Issue.record("a timeout was read as a plain refusal")
            return
        }
        #expect(said.contains("a/b"))
        #expect(!said.contains("nothing was reported"))
    }

    @Test("only a gh that does not know the flag is retried, not one that refused the upload")
    func onlyAnUnknownFlagIsRetried() {
        #expect(GitHub.cannotAttach("unknown flag: --attach"))
        #expect(GitHub.cannotAttach("unknown shorthand flag: 'a' in -attach"))
        #expect(!GitHub.cannotAttach("failed to upload two.png: HTTP 502"))
        #expect(!GitHub.cannotAttach("--attach is not a valid image"))
        #expect(!GitHub.cannotAttach("gh: Not Found (HTTP 404)"))
    }
}
