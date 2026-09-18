import Foundation
import Testing
@testable import Core

@Suite("Reading Grok's saved sign-in")
struct GrokAuthDecodingTests {
    private func account(expiringAt value: String) -> AgentCatalog.GrokAccount? {
        AgentCatalog.decodeGrokAuth(Data(#"{"default": {"email": "a@b.c", "expires_at": \#(value)}}"#.utf8))
    }

    @Test("an expiry written as a date is read as that date")
    func textExpiry() {
        #expect(account(expiringAt: #""2026-01-02T03:04:05Z""#)?.expiresAt == Date(timeIntervalSince1970: 1_767_323_045))
    }

    @Test("an expiry written as seconds is read as that moment")
    func numericExpiry() {
        #expect(account(expiringAt: "1767323045")?.expiresAt == Date(timeIntervalSince1970: 1_767_323_045))
    }

    @Test("an expiry of any other shape is left unknown")
    func otherExpiry() {
        let found = account(expiringAt: "{}")
        #expect(found?.email == "a@b.c")
        #expect(found?.expiresAt == nil)
    }
}
