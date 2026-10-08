import Foundation
import Testing
@testable import Core

@Suite("The issue a report becomes")
struct IssueReportTests {
    private func environment() -> Feedback.Environment {
        FeedbackFixture.environment()
    }

    private func body(
        message: String = "x", kind: Feedback.Kind = .report, logs: String? = nil, images: Int = 0
    ) -> String {
        IssueReport.body(
            message: message, kind: kind, environment: environment(), logs: logs, imageCount: images
        )
    }

    @Test("the title is the first line, and it says which kind of report it is")
    func titleIsTheFirstLine() {
        let title = IssueReport.title(
            from: "The sidebar loses its selection\n\nAnd then it scrolls.", kind: .report
        )

        #expect(title == "Feedback: The sidebar loses its selection")
    }

    @Test("a long first line is cut on the last whole word that fits")
    func longTitlesAreCut() {
        let words = Array(repeating: "sidebar", count: 40).joined(separator: " ")
        let title = IssueReport.title(from: words, kind: .report)

        #expect(title.count <= IssueReport.titleLimit)
        #expect(title.hasSuffix("sidebar…"))
        #expect(title == "Feedback: sidebar sidebar sidebar sidebar sidebar sidebar sidebar sidebar…")
    }

    @Test("a first line typed with Windows line endings leaves no control character behind")
    func carriageReturnsAreTrimmed() {
        let title = IssueReport.title(from: "Crash on open\r\nSteps:\r\n", kind: .report)

        #expect(title == "Feedback: Crash on open")
    }

    @Test("a report with no words at all still gets a title somebody can read")
    func emptyStillHasATitle() {
        #expect(IssueReport.title(from: "   \n  ", kind: .report) == "Feedback from the app")
        #expect(IssueReport.title(from: "", kind: .prompt) == "Prompt suggestion from the app")
    }

    @Test("the body carries the message, then the environment, then the logs")
    func bodyIsInThatOrder() throws {
        let written = body(message: "It loses the selection.", logs: "a log line")
        let message = try #require(written.range(of: "It loses the selection."))
        let environmentHeading = try #require(written.range(of: "app_version"))
        let logs = try #require(written.range(of: "a log line"))

        #expect(message.lowerBound < environmentHeading.lowerBound)
        #expect(environmentHeading.lowerBound < logs.lowerBound)
    }

    @Test("the environment is a markdown table of exactly the fields the report collected")
    func environmentIsATable() {
        let written = body()
        let rows = written
            .split(separator: "\n")
            .filter { $0.hasPrefix("| ") && $0 != "| --- | --- |" && $0 != "| Field | Value |" }

        #expect(written.contains("| Field | Value |\n| --- | --- |\n"))
        #expect(rows.count == environment().fields.count)
        for field in environment().fields {
            #expect(rows.contains { $0.hasPrefix("| \(field.name) | ") })
        }
    }

    @Test("a field is written as a reader reads it, whatever kind of value it holds")
    func everyKindOfValueIsReadable() {
        let written = body()

        #expect(written.contains("| app_version | 0.4.0 |"))
        #expect(written.contains("| translated | no |"))
        #expect(written.contains("| available_agents | claude, codex |"))
        #expect(written.contains("| display_scale | 2 |"))
    }

    @Test("the logs go in a fence that closes, so a log line cannot be read as markdown")
    func logsAreFenced() {
        let written = body(logs: "# not a heading\n- not a list")
        let fences = written.components(separatedBy: IssueReport.fence).count - 1

        #expect(fences == 2)
        #expect(written.contains("```\n# not a heading\n- not a list\n```"))
    }

    @Test("logs longer than the limit are cut at the oldest end, keeping the newest lines")
    func longLogsAreCut() {
        let logs = (1...5_000).map { "line \($0)" }.joined(separator: "\n")
        let written = body(logs: logs)

        #expect(written.count < logs.count)
        #expect(written.contains("line 5000"))
        #expect(!written.contains("line 1\n"))
        #expect(!written.contains("\n\(AppLogExcerpt.elision) "))
        #expect(written.contains(AppLogExcerpt.elision))
    }

    @Test("a message longer than a report may carry is cut to the length the sheet promised")
    func longMessagesAreCut() {
        let written = body(message: String(repeating: "x", count: Feedback.maxMessageCharacters + 500))

        #expect(!written.contains(String(repeating: "x", count: Feedback.maxMessageCharacters + 1)))
        #expect(written.contains(String(repeating: "x", count: Feedback.maxMessageCharacters)))
    }

    @Test("the body holds the message and the environment, and nothing else the app knows")
    func nothingPrivateInTheBody() {
        let written = body(message: "written by kid@example.com himself")
        let names = environment().fields.map(\.name)

        #expect(written.contains("kid@example.com"))
        #expect(!written.contains(FeedbackFixture.token))
        #expect(!names.contains { $0.contains("token") || $0.contains("email") || $0 == "name" })
    }

    @Test("a report with pictures says how many are coming, so the reader waits for them")
    func picturesAreAnnounced() {
        #expect(body(images: 2).contains("2 screenshots belong with this report"))
        #expect(body(images: 1).contains("1 screenshot belong"))
        #expect(!body(images: 0).lowercased().contains("screenshot"))
    }

    @Test("a cut that lands inside the log fence closes it before the notice")
    func aCutClosesTheFence() {
        let open = "### Recent app logs\n\n```\nline one\nline two"
        let closed = IssueReport.cut(open)

        #expect(closed.components(separatedBy: IssueReport.fence).count - 1 == 2)
        #expect(closed.hasSuffix(AppRepository.cutNotice))
        #expect(closed.contains("line two\n```"))
    }

    @Test("a cut that lands outside the fence adds no fence of its own")
    func aBalancedCutIsLeftAlone() {
        let balanced = "a message\n\n```\nlogs\n```"

        #expect(IssueReport.cut(balanced) == balanced + AppRepository.cutNotice)
    }

    @Test("a prompt suggestion is labelled as one, and a report as a report")
    func labelsByKind() {
        #expect(IssueReport.labels(for: .report) == ["bug"])
        #expect(IssueReport.labels(for: .prompt) == ["enhancement"])
    }
}
