import Foundation
import Testing
@testable import Core

@Suite("The repository this app belongs to")
struct AppRepositoryTests {
    private func body(of url: URL) -> String {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "body" }?.value ?? ""
    }

    @Test("the slug is owner and name, and the page is built from it")
    func slugAndPage() {
        #expect(AppRepository.slug == "akira-foundation/unified-dev-swift")
        #expect(AppRepository.page.absoluteString == "https://github.com/akira-foundation/unified-dev-swift")
        #expect(
            AppRepository.issuesURL.absoluteString
                == "https://github.com/akira-foundation/unified-dev-swift/issues"
        )
    }

    @Test("the help link the menu opens is this repository's readme")
    func helpGoesToTheReadme() {
        #expect(
            AppRepository.readmeURL.absoluteString
                == "https://github.com/akira-foundation/unified-dev-swift/blob/main/README.md"
        )
    }

    @Test("the updater asks GitHub about this repository and no other")
    func theUpdaterAgrees() {
        #expect(
            SoftwareUpdate.latestReleaseURL.absoluteString
                == "https://api.github.com/repos/akira-foundation/unified-dev-swift/releases/latest"
        )
    }

    @Test("a new issue URL carries the title and the body, escaped")
    func newIssueCarriesBoth() throws {
        let url = AppRepository.newIssueURL(title: "A & B", body: "line one\nline two")
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = components.queryItems ?? []

        #expect(components.path.hasSuffix("/issues/new"))
        #expect(items.first { $0.name == "title" }?.value == "A & B")
        #expect(items.first { $0.name == "body" }?.value == "line one\nline two")
        #expect(!url.absoluteString.contains(" "))
    }

    @Test("a report written in Portuguese reaches the page as the words that were typed")
    func accentedTextSurvivesTheLink() throws {
        let url = AppRepository.newIssueURL(
            title: "Não abre o painel", body: "A barra lateral perdeu a selecção"
        )
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)

        #expect(url.absoluteString.contains("N%C3%A3o"))
        #expect(items.first { $0.name == "title" }?.value == "Não abre o painel")
        #expect(body(of: url) == "A barra lateral perdeu a selecção")
    }

    @Test("the labels a report carries reach the page as well")
    func newIssueCarriesLabels() throws {
        let url = AppRepository.newIssueURL(title: "t", body: "b", labels: ["bug", "needs triage"])
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(components.queryItems?.first { $0.name == "labels" }?.value == "bug,needs triage")
        #expect(!AppRepository.newIssueURL(title: "t", body: "b").absoluteString.contains("labels"))
    }

    @Test("a body too long for a URL is cut, and says it was")
    func longBodiesAreCut() {
        let url = AppRepository.newIssueURL(
            title: "Long", body: String(repeating: "x", count: 20_000)
        )

        #expect(url.absoluteString.count <= AppRepository.urlLimit)
        #expect(body(of: url).hasSuffix("cut off here because it did not fit in a link."))
    }

    @Test("a cut keeps as much of the report as the link has room for")
    func aCutKeepsWhatFits() {
        let url = AppRepository.newIssueURL(
            title: "Long", body: String(repeating: "x", count: 20_000)
        )
        let kept = body(of: url).replacingOccurrences(of: AppRepository.cutNotice, with: "")

        #expect(kept.count > 5_000)
        #expect(url.absoluteString.count > AppRepository.urlLimit - 100)
    }

    @Test("a report of emoji is cut to what fits rather than thrown away")
    func wideCharactersAreNotThrownAway() {
        let url = AppRepository.newIssueURL(
            title: "Wide", body: String(repeating: "🙂", count: 1_000)
        )
        let kept = body(of: url).replacingOccurrences(of: AppRepository.cutNotice, with: "")

        #expect(url.absoluteString.count <= AppRepository.urlLimit)
        #expect(kept.count > 400)
    }

    @Test("a title that alone will not fit is cut too, rather than overflowing the link")
    func longTitlesCannotOverflow() {
        let url = AppRepository.newIssueURL(
            title: String(repeating: "x", count: 20_000), body: "a short body"
        )

        #expect(url.absoluteString.count <= AppRepository.urlLimit)
    }

    @Test("the caller decides what a cut body ends with")
    func theCallerClosesTheCut() {
        let url = AppRepository.newIssueURL(
            title: "Long", body: String(repeating: "x", count: 20_000),
            cut: { $0 + "[cut by the caller]" }
        )

        #expect(body(of: url).hasSuffix("[cut by the caller]"))
        #expect(!body(of: url).contains("did not fit in a link"))
    }
}
