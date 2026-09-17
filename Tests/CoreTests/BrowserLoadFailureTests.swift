import Foundation
import Testing
@testable import Core

@Suite("What a browser pane says when a page will not load")
struct BrowserLoadFailureTests {
    private func failure(_ code: Int, host: String? = nil) -> BrowserLoadFailure? {
        BrowserLoadFailure.of(domain: NSURLErrorDomain, code: code, host: host)
    }

    @Test("an address with no server behind it is named and explained")
    func unknownHost() throws {
        let f = try #require(failure(NSURLErrorCannotFindHost, host: "qsdlqsdfjm.be"))
        #expect(f.title == "Cannot find that address")
        #expect(f.message.contains("qsdlqsdfjm.be"))
        #expect(f.message.contains("spelling"))
    }

    @Test("the failures that are not failures say nothing")
    func silentOnes() {
        #expect(failure(NSURLErrorCancelled) == nil)
        #expect(BrowserLoadFailure.of(domain: "WebKitErrorDomain", code: 102) == nil)
        #expect(BrowserLoadFailure.of(domain: "WebKitErrorDomain", code: 101) == nil)
    }

    @Test("a failure with no host to name still reads")
    func noHost() throws {
        let f = try #require(failure(NSURLErrorCannotConnectToHost))
        #expect(!f.message.contains("%@"))
        #expect(f.message.hasPrefix("The server refused"))

        let named = try #require(failure(NSURLErrorCannotConnectToHost, host: "localhost:3000"))
        #expect(named.message.hasPrefix("localhost:3000 refused"))
    }

    @Test("an empty host is treated as no host")
    func emptyHost() throws {
        let f = try #require(failure(NSURLErrorTimedOut, host: ""))
        #expect(f.message.hasPrefix("The server did not answer"))
    }

    @Test("a failure about the machine does not blame the page")
    func offline() throws {
        let f = try #require(failure(NSURLErrorNotConnectedToInternet))
        #expect(f.title == "No internet connection")
        #expect(!f.namesTheAddress)
    }

    @Test("every certificate failure is one sentence about trust")
    func certificates() throws {
        for code in [
            NSURLErrorSecureConnectionFailed,
            NSURLErrorServerCertificateUntrusted,
            NSURLErrorServerCertificateHasBadDate,
            NSURLErrorServerCertificateHasUnknownRoot,
            NSURLErrorServerCertificateNotYetValid,
        ] {
            let f = try #require(failure(code, host: "example.test"))
            #expect(f.title == "The connection is not private")
            #expect(f.message.contains("example.test"))
        }
    }

    @Test("an error nothing recognises still says something")
    func unknown() throws {
        let f = try #require(failure(-4242))
        #expect(f.title == "This page did not load")
        let other = try #require(BrowserLoadFailure.of(domain: "SomeOtherDomain", code: 7))
        #expect(other.title == "This page did not load")
    }

    @Test("a local file that is gone says so")
    func missingFile() throws {
        let f = try #require(failure(NSURLErrorFileDoesNotExist))
        #expect(f.title == "That file is not there")
    }
}
