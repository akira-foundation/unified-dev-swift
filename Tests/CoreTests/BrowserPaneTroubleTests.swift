import Testing
import Foundation
@testable import Core

@Suite("What a browser pane says when its page did not load")
struct BrowserPaneTroubleTests {
    private static func report(failure: BrowserLoadFailure?) -> BrowserPaneReport {
        BrowserPaneReport(
            number: 1,
            name: "Service Tokens",
            address: "http://there-there-6.test/",
            failure: failure
        )
    }

    @Test func aPaneShowingAPageHasNothingToSay() {
        let report = Self.report(failure: nil)
        #expect(report.trouble == nil)
        #expect(report.json.objectValue?["failed_to_load"] == .null)
    }

    @Test func namesWhatWentWrongInTheSameWordsThePaneDraws() throws {
        let failure = try #require(
            BrowserLoadFailure.of(
                domain: NSURLErrorDomain,
                code: NSURLErrorCannotConnectToHost,
                host: "there-there-6.test"
            )
        )
        let trouble = try #require(Self.report(failure: failure).trouble)

        #expect(trouble.contains("Cannot connect"))
        #expect(trouble.contains("there-there-6.test"))
        #expect(trouble.contains("not the pane failing to draw"))
    }

    @Test func leavesTheAddressOutWhereItIsNotTheSubject() {
        let failure = BrowserLoadFailure.of(
            domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet
        )
        let trouble = Self.report(failure: failure).trouble

        #expect(trouble?.contains("there-there-6.test") == false)
        #expect(trouble?.contains("No internet connection") == true)
    }

    @Test func carriesItOnTheObjectBrowserReadAnswersWith() {
        let failure = BrowserLoadFailure.of(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        let json = Self.report(failure: failure).json

        #expect(json["failed_to_load"]?.stringValue?.contains("took too long") == true)
    }

    @Test func saysNothingAboutTheFailuresThatAreNotFailures() {
        #expect(BrowserLoadFailure.of(domain: NSURLErrorDomain, code: NSURLErrorCancelled) == nil)
        #expect(BrowserLoadFailure.of(domain: "WebKitErrorDomain", code: 102) == nil)
        #expect(BrowserLoadFailure.of(domain: "WebKitErrorDomain", code: 101) == nil)
    }
}
