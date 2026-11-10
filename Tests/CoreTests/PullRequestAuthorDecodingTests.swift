import Testing
import Foundation
@testable import Core

@Suite("A pull request's author and fork")
struct PullRequestAuthorDecodingTests {
    private func payload(extra: String) -> Data {
        Data("""
        {"number": 1, "title": "t", "url": "u", "state": "OPEN", "isDraft": false,
         "headRefName": "feature", "baseRefName": "develop", "headRefOid": "abc"\(extra)}
        """.utf8)
    }

    @Test func theAuthorAndForkAreReadFromThePayload() throws {
        let pullRequest = try GitHub.decodePullRequest(
            from: payload(extra: #", "author": {"login": "owner"}, "isCrossRepository": true"#)
        )

        #expect(pullRequest.author == "owner")
        #expect(pullRequest.isFromFork == true)
    }

    @Test func aPayloadWithoutThemLeavesThemUnknown() throws {
        let pullRequest = try GitHub.decodePullRequest(from: payload(extra: ""))

        #expect(pullRequest.author == nil)
        #expect(pullRequest.isFromFork == nil)
    }
}
