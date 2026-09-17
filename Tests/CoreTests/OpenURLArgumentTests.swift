import Foundation
import Testing
@testable import Core

@Suite("Opening a URL given on the command line")
struct OpenURLArgumentTests {
    @Test("a properly encoded link is passed through byte for byte")
    func encodedLinkIsUntouched() {
        let argument = "unifieddev://prompt=fix%20the%20bug&path=/tmp/x"
        #expect(OpenURLArgument.url(from: argument)?.absoluteString == argument)
    }

    @Test("a colon in the prompt no longer loses the whole link")
    func colonSurvives() throws {
        let url = try #require(
            OpenURLArgument.url(from: "unifieddev://prompt=fix: the bug&path=/tmp/x")
        )
        #expect(url.scheme == "unifieddev")
        #expect(url.absoluteString == "unifieddev://prompt=fix%3A%20the%20bug&path=%2Ftmp%2Fx")
    }

    @Test("a repaired prompt decodes back to exactly what was typed")
    func repairedPromptRoundTrips() throws {
        let typed = "fix: the bug, 100% of the time + tests"
        let url = try #require(OpenURLArgument.url(from: "unifieddev://prompt=\(typed)&path=/tmp/x"))

        let payload = url.absoluteString.replacing("unifieddev://", with: "")
        let pairs = payload.split(separator: "&").map {
            $0.split(separator: "=", maxSplits: 1).map(String.init)
        }
        let prompt = try #require(pairs.first { $0.first == "prompt" }?.last)
        #expect(prompt.replacing("+", with: " ").removingPercentEncoding == typed)
    }

    @Test("the pair structure is kept, so the path stays its own value")
    func pairsAreKept() throws {
        let url = try #require(
            OpenURLArgument.url(from: "unifieddev://prompt=do the thing&path=/Users/x/dev/repo")
        )
        let payload = url.absoluteString.replacing("unifieddev://", with: "")
        let keys = payload.split(separator: "&").map { String($0.split(separator: "=")[0]) }
        #expect(keys == ["prompt", "path"])
    }

    @Test("text with no scheme is refused rather than guessed at", arguments: [
        "", "fix the bug", "://prompt=x", "1bad://prompt=x", "no scheme here: none",
    ])
    func schemelessTextIsRefused(argument: String) {
        #expect(OpenURLArgument.url(from: argument) == nil)
    }

    @Test("the dev scheme repairs under its own name, not under unifieddev's")
    func otherSchemesRepairToo() throws {
        let url = try #require(OpenURLArgument.url(from: "unifieddevdev://prompt=two words&path=/t"))
        #expect(url.scheme == "unifieddevdev")
    }
}
