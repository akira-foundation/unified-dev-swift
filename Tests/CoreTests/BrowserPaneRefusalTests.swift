import Foundation
import Testing
@testable import Core

@Suite("What an agent gets from the owner's browser panes")
struct BrowserPaneRefusalTests {
    private let secretAddress = "https://bank.example/account/42?token=abc"

    private func shared(_ number: Int, address: String = "http://localhost:3000") -> BrowserPaneReport {
        BrowserPaneReport(number: number, name: "Preview", address: address, access: .agents)
    }

    private func owners(_ number: Int) -> BrowserPaneReport {
        BrowserPaneReport(
            number: number, name: "Bank", address: secretAddress, pageTitle: "Balance", isLoading: true,
            canGoBack: true, canGoForward: true, failure: BrowserLoadFailure.of(domain: "NSURLErrorDomain", code: -1009, host: "bank.example"),
            access: .owner
        )
    }

    private func refusal(
        number: Int?, among browsers: [BrowserPaneReport]
    ) throws -> String {
        guard case .failure(let refusal) = BrowserPaneChoice.choose(
            number: number, among: browsers, tool: "browser_text"
        ) else {
            Issue.record("expected a refusal")
            return ""
        }
        return refusal.sentence
    }

    @Test("Naming the owner's pane is refused, whatever the agent asked for")
    func aNamedOwnersPaneIsRefused() throws {
        let sentence = try refusal(number: 1, among: [owners(1), shared(2)])
        #expect(sentence == BrowserPaneAccess.refusal(number: 1, tool: "browser_text"))
    }

    @Test("A report that says agents may not use it is refused even if it carries an address")
    func theAccessDecidesNotTheShapeOfTheReport() throws {
        let sentence = try refusal(number: 1, among: [owners(1)])
        #expect(sentence == BrowserPaneAccess.refusal(number: 1, tool: "browser_text"))
    }

    @Test("With no number, the only pane open to agents is the one meant")
    func noNumberFindsTheOnlySharedPane() {
        let outcome = BrowserPaneChoice.choose(
            number: nil, among: [owners(1), shared(2)], tool: "browser_text"
        )
        #expect((try? outcome.get()) == shared(2))
    }

    @Test("With no number and only the owner's panes open, the refusal says whose they are")
    func noNumberAndOnlyOwnersPanes() throws {
        let sentence = try refusal(number: nil, among: [owners(3)])
        #expect(sentence == BrowserPaneAccess.refusal(number: 3, tool: "browser_text"))
    }

    @Test("With no number and several shared panes, only the shared ones are listed")
    func severalSharedPanesNeedANumber() throws {
        let sentence = try refusal(
            number: nil, among: [owners(1), shared(2), shared(3, address: "http://x.test")]
        )
        #expect(sentence.contains("2 browsers open to you"))
        #expect(sentence.contains("2 on http://localhost:3000"))
        #expect(!sentence.contains("the owner's"))
    }

    @Test("A wrong number lists the owner's pane without saying what it shows")
    func aWrongNumberDoesNotDescribeTheOwnersPane() throws {
        let sentence = try refusal(number: 9, among: [owners(1), shared(2)])
        #expect(sentence.contains("1, the owner's"))
        #expect(!sentence.contains("bank.example"))
    }

    @Test("A report of the owner's pane carries nothing about the page, whatever it was built from")
    func anOwnersReportIsEmpty() {
        let report = owners(4)
        #expect(report.number == 4)
        #expect(report.name == "Owner's browser")
        #expect(report.address.isEmpty)
        #expect(report.pageTitle.isEmpty)
        #expect(!report.isLoading && !report.canGoBack && !report.canGoForward)
        #expect(report.failure == nil)
        #expect(report.trouble == nil)
    }

    @Test("A report of a shared pane keeps what it was given")
    func aSharedReportIsWhole() {
        let report = BrowserPaneReport(
            number: 2, name: "Preview", address: "http://x.test", pageTitle: "X", isLoading: true,
            canGoBack: true, canGoForward: true, access: .agents
        )
        #expect(report.name == "Preview" && report.address == "http://x.test" && report.pageTitle == "X")
        #expect(report.isLoading && report.canGoBack && report.canGoForward)
    }

    @Test("A row for the owner's browser takes the withheld name, whatever name it was given")
    func aCensusRowWithholdsTheName() {
        let row = PaneCensusEntry(kind: .browser, name: "Bank", isShowing: true, browser: owners(1))
        #expect(row.name == "Owner's browser")
        #expect(PaneCensusEntry(kind: .chat, name: "Bridge", isShowing: true).name == "Bridge")
    }

    @Test("Both listings say whether agents may use the pane, for both kinds of pane")
    func theListingsCarryTheAccess() throws {
        for (report, expected) in [(owners(1), false), (shared(2), true)] {
            guard case .object(let fields) = report.json else {
                Issue.record("expected an object")
                return
            }
            #expect(fields["open_to_agents"] == .bool(expected))
            let entry = PaneCensusEntry(kind: .browser, name: "Preview", isShowing: true, browser: report)
            guard case .object(let row) = entry.json else {
                Issue.record("expected an object")
                return
            }
            #expect(row["open_to_agents"] == .bool(expected))
        }
        guard case .object(let fields) = owners(1).json else { return }
        #expect(fields["address"] == .string(""))
    }
}
