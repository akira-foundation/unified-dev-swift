import Foundation
import Testing
@testable import Core

@Suite("Feedback: the address")
struct FeedbackEmailTests {
    private func submission(email: String?) -> Feedback.PromptSubmission {
        Feedback.PromptSubmission(
            prompt: "make it narrower", name: nil, email: email, token: nil, environment: FeedbackFixture.environment()
        )
    }

    private func reportWithAPicture(email: String?) -> Feedback.Report {
        FeedbackFixture.report(
            email: email,
            logs: "a line of log",
            images: [Feedback.Image(contentType: "image/png", data: FeedbackFixture.pngBytes)]
        )
    }

    @Test("a report carries the address it was given")
    func reportCarriesTheAddress() throws {
        #expect(try FeedbackFixture.object(FeedbackFixture.report(email: "freek@akira-io.com"))["email"] as? String == "freek@akira-io.com")
    }

    @Test("a report with pictures still carries the address it was given")
    func multipartReportKeepsTheAddress() throws {
        let body = try Feedback.body(for: reportWithAPicture(email: "freek@akira-io.com"), boundary: "B")

        #expect(body.contentType == "multipart/form-data; boundary=B")
        #expect(FeedbackFixture.text(of: body).contains("name=\"email\"\r\n\r\nfreek@akira-io.com\r\n"))
    }

    @Test("every field the JSON body has is a part of the multipart body too")
    func multipartAndJSONCarryTheSameFields() throws {
        let sent = reportWithAPicture(email: "freek@akira-io.com")
        let written = FeedbackFixture.text(of: try Feedback.body(for: sent, boundary: "B"))
        let json = try FeedbackFixture.object(sent)

        #expect(json.keys.sorted() == ["email", "environment", "logs", "message", "token"])
        for key in json.keys where key != "environment" {
            #expect(written.contains("name=\"\(key)\"\r\n\r\n"))
        }
    }

    @Test("a report with pictures and no address has no address part at all")
    func multipartReportWithoutAddress() throws {
        let written = FeedbackFixture.text(of: try Feedback.body(for: reportWithAPicture(email: nil), boundary: "B"))

        #expect(!written.contains("name=\"email\""))
    }

    @Test("a prompt submission carries it too")
    func promptCarriesTheAddress() throws {
        #expect(try FeedbackFixture.object(submission(email: "freek@akira-io.com"))["email"] as? String == "freek@akira-io.com")
    }

    @Test("no address means no key at all, rather than a key holding an empty string")
    func absentIsAbsent() throws {
        #expect(try FeedbackFixture.object(FeedbackFixture.report(email: nil))["email"] == nil)
        #expect(try FeedbackFixture.object(FeedbackFixture.report(email: "   "))["email"] == nil)
        #expect(try FeedbackFixture.object(submission(email: nil))["email"] == nil)
    }

    @Test("an address the endpoint would refuse is left out rather than sent to be rejected")
    func refusableAddressIsDropped() throws {
        let json = try FeedbackFixture.object(FeedbackFixture.report(email: "not an address"))

        #expect(json["email"] == nil)
        #expect(json["message"] as? String == "the sidebar flickers")
    }

    @Test("surrounding whitespace goes, and the case of the local part does not")
    func normalising() {
        #expect(Feedback.normalisedEmail("  Freek@Akira-Io.com  ") == "Freek@Akira-Io.com")
        #expect(Feedback.normalisedEmail(String(repeating: "a", count: 300)).count == 254)
    }

    @Test("an empty field is acceptable, because hearing back is opted into rather than required")
    func emptyIsAcceptable() {
        #expect(Feedback.isAcceptableEmail(""))
        #expect(Feedback.isAcceptableEmail("   "))
    }

    @Test("what the sheet accepts and what it warns about")
    func acceptance() {
        #expect(Feedback.isAcceptableEmail("freek@akira-io.com"))
        #expect(Feedback.isAcceptableEmail("freek+unifieddev@akira-io.co.uk"))
        #expect(Feedback.isAcceptableEmail("a@b.c"))

        #expect(!Feedback.isAcceptableEmail("freek"))
        #expect(!Feedback.isAcceptableEmail("freek@akira-io"))
        #expect(!Feedback.isAcceptableEmail("freek @akira-io.com"))
        #expect(!Feedback.isAcceptableEmail("freek@@akira-io.com"))
        #expect(!Feedback.isAcceptableEmail("@akira-io.com"))
    }

    @Test("the name field still refuses an address, and now says where to put it")
    func theNameFieldStillRefusesOne() {
        #expect(!Feedback.isAcceptableName("freek@akira-io.com"))
        #expect(Feedback.nameProblem.contains("field of its own"))
    }

    @Test("a half-typed field is unfinished, not wrong, until Send is pressed")
    func nothingIsWrongBeforeASendIsAttempted() {
        let problems = Feedback.sheetProblems(
            name: "freek@akira-io.com", email: "freek@akira-io.", afterSendAttempt: false
        )
        #expect(problems.isEmpty)
        #expect(problems.firstField == nil)
    }

    @Test("after a send is attempted, each field says what is wrong with it")
    func problemsAfterAnAttempt() {
        let problems = Feedback.sheetProblems(
            name: "freek@akira-io.com", email: "freek@akira-io.", afterSendAttempt: true
        )
        #expect(problems.name == Feedback.nameProblem)
        #expect(problems.email == Feedback.emailProblem)
        #expect(problems.message(for: .name) == Feedback.nameProblem)
        #expect(problems.message(for: .email) == Feedback.emailProblem)
    }

    @Test("empty optional fields are never a problem, even on the way out")
    func emptyIsNeverAProblem() {
        let problems = Feedback.sheetProblems(name: "", email: "", afterSendAttempt: true)
        #expect(problems.isEmpty)

        let padded = Feedback.sheetProblems(name: "  ", email: "   ", afterSendAttempt: true)
        #expect(padded.isEmpty)
    }

    @Test("a corrected field stops being a problem the moment it is corrected")
    func correctionClears() {
        let problems = Feedback.sheetProblems(
            name: "Freek", email: "freek@akira-io.com", afterSendAttempt: true
        )
        #expect(problems.isEmpty)
    }

    @Test("the first refused field is the one focus should land in")
    func focusOrder() {
        let both = Feedback.sheetProblems(
            name: "freek@akira-io.com", email: "nope", afterSendAttempt: true
        )
        #expect(both.firstField == .name)

        let emailOnly = Feedback.sheetProblems(
            name: "Freek", email: "nope", afterSendAttempt: true
        )
        #expect(emailOnly.firstField == .email)
    }

    @Test("a sheet without a name field can only be refused over its address")
    func sheetWithoutANameField() {
        let problems = Feedback.sheetProblems(email: "nope", afterSendAttempt: true)
        #expect(problems.name == nil)
        #expect(problems.firstField == .email)
    }

    @Test("the logs checkbox starts ticked, and an untick is remembered over the default")
    func logsCheckboxMemory() throws {
        let suite = "unifieddev.tests.feedback-logs.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(Feedback.includesLogs(defaults) == Feedback.includesLogsByDefault)
        #expect(Feedback.includesLogsByDefault)

        Feedback.rememberIncludesLogs(false, in: defaults)
        #expect(!Feedback.includesLogs(defaults))

        Feedback.rememberIncludesLogs(true, in: defaults)
        #expect(Feedback.includesLogs(defaults))
    }
}
