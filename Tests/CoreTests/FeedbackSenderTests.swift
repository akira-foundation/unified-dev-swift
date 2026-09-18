import Foundation
import Testing
@testable import Core

@Suite("Feedback: the sender")
struct FeedbackSenderTests {
    private static func scratchSuite() -> String {
        "unifieddev.tests.feedback-sender.\(UUID().uuidString)"
    }

    @Test("nothing is remembered before anything has been sent")
    func startsEmpty() throws {
        let suite = Self.scratchSuite()
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(Feedback.rememberedSender(defaults) == Feedback.Sender(name: "", email: ""))
    }

    @Test("a sent prompt remembers the name and the address the way they were sent")
    func aSentPromptRemembersBoth() throws {
        let suite = Self.scratchSuite()
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        Feedback.rememberSender(name: " @Seb ", email: "  seb@example.com ", in: defaults)

        #expect(Feedback.rememberedSender(defaults) == Feedback.Sender(name: "Seb", email: "seb@example.com"))
    }

    @Test("a sent report has no name field, so the name remembered before it stays")
    func aSentReportKeepsTheName() throws {
        let suite = Self.scratchSuite()
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        Feedback.rememberSender(name: "Seb", email: "seb@example.com", in: defaults)
        Feedback.rememberSender(name: nil, email: "seb@example.org", in: defaults)

        #expect(Feedback.rememberedSender(defaults) == Feedback.Sender(name: "Seb", email: "seb@example.org"))
    }

    @Test("sending with the address cleared is asking for it to be forgotten")
    func aClearedAddressIsForgotten() throws {
        let suite = Self.scratchSuite()
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        Feedback.rememberSender(name: "Seb", email: "seb@example.com", in: defaults)
        Feedback.rememberSender(name: "Seb", email: "", in: defaults)

        #expect(Feedback.rememberedSender(defaults) == Feedback.Sender(name: "Seb", email: ""))
    }

    @Test("an address the endpoint would refuse never replaces the one already remembered")
    func aRefusedAddressIsNotRemembered() throws {
        let suite = Self.scratchSuite()
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        Feedback.rememberSender(name: "Seb", email: "seb@example.com", in: defaults)
        Feedback.rememberSender(name: "Seb", email: "seb@example.", in: defaults)

        #expect(Feedback.rememberedSender(defaults).email == "seb@example.com")
    }

    @Test("a name the endpoint would refuse never replaces the one already remembered")
    func aRefusedNameIsNotRemembered() throws {
        let suite = Self.scratchSuite()
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        Feedback.rememberSender(name: "Seb", email: "seb@example.com", in: defaults)
        Feedback.rememberSender(name: "seb@example.com", email: "seb@example.com", in: defaults)

        #expect(Feedback.rememberedSender(defaults).name == "Seb")
    }

    @Test("what is remembered is what a submission would have carried")
    func whatIsRememberedIsWhatWasSent() throws {
        let suite = Self.scratchSuite()
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        for typed in [" @Seb ", "Seb", "seb@example.com", ""] {
            Feedback.rememberSender(name: typed, email: "seb@example.com", in: defaults)
            let remembered = Feedback.rememberedSender(defaults).name
            let submitted = Feedback.PromptSubmission(
                prompt: "Group workspaces by project",
                name: remembered.isEmpty ? nil : remembered,
                email: "seb@example.com",
                token: nil,
                environment: FeedbackFixture.environment()
            )

            #expect(submitted.name == (remembered.isEmpty ? nil : remembered))
        }
    }

    @Test("the sender is kept under keys of its own, beside the logs checkbox")
    func theKeysAreTheirOwn() {
        let keys = [Feedback.senderNameKey, Feedback.senderEmailKey, Feedback.includesLogsKey]

        #expect(Set(keys).count == keys.count)
        #expect(keys.allSatisfy { $0.hasPrefix("feedback.") })
    }
}
