import Foundation
import Testing
@testable import Core

@Suite("Agent question collapse")
struct AgentQuestionCollapseTests {
    private var database: AgentQuestion {
        AgentQuestion(
            question: "Which database should this use?",
            header: "Storage",
            options: [
                AgentQuestion.Option(label: "SQLite", description: "One file, no server."),
                AgentQuestion.Option(label: "Postgres", description: "A server, and a schema."),
            ],
            answerID: "q1"
        )
    }

    private var drivers: AgentQuestion {
        AgentQuestion(
            question: "Which drivers should ship?",
            header: "Drivers",
            multiSelect: true,
            options: [
                AgentQuestion.Option(label: "iCloud"),
                AgentQuestion.Option(label: "Dropbox"),
                AgentQuestion.Option(label: "S3"),
            ],
            answerID: "q2"
        )
    }

    @Test("a question nobody has answered yet is open, and answering it closes it")
    func theRule() {
        #expect(AgentQuestionDisclosure.isOpen(isSettled: false, wasReopened: false))
        #expect(!AgentQuestionDisclosure.isOpen(isSettled: true, wasReopened: false))
    }

    @Test("an answered question reopened by hand stays open, and a pending one cannot be shut")
    func reopening() {
        #expect(AgentQuestionDisclosure.isOpen(isSettled: true, wasReopened: true))
        #expect(AgentQuestionDisclosure.isOpen(isSettled: false, wasReopened: true))
    }

    @Test("the chosen option is written out in full, and is the one marked when the card reopens")
    func chosenOption() throws {
        let digest = try #require(
            AgentQuestionDigest.of([database], answers: ["q1": "Postgres"]).first
        )

        #expect(digest.answer == .chosen(["Postgres"]))
        #expect(digest.answerText == "Postgres")
        #expect(digest.chosen == ["Postgres"])
        #expect(!digest.isTyped)
        #expect(digest.question == "Which database should this use?")
        #expect(digest.header == "Storage")
    }

    @Test("several ticks come back in the order they were offered, all of them marked")
    func severalTicks() throws {
        let digest = try #require(
            AgentQuestionDigest.of([drivers], answers: ["q2": "S3, iCloud"]).first
        )

        #expect(digest.answer == .chosen(["iCloud", "S3"]))
        #expect(digest.answerText == "iCloud, S3")
        #expect(digest.chosen == ["iCloud", "S3"])
    }

    @Test("words the owner typed are shown as his own, not mistaken for an option")
    func typedAnswer() throws {
        let digest = try #require(
            AgentQuestionDigest.of([database], answers: ["q1": "a managed Postgres"]).first
        )

        #expect(digest.answer == .typed("a managed Postgres"))
        #expect(digest.answerText == "a managed Postgres")
        #expect(digest.isTyped)
        #expect(digest.chosen.isEmpty)
    }

    @Test("typed words that open with an option label are still the owner's own words")
    func typedAnswerThatQuotesAnOption() throws {
        let digest = try #require(
            AgentQuestionDigest.of([database], answers: ["q1": "Postgres, but hosted"]).first
        )

        #expect(digest.answer == .typed("Postgres, but hosted"))
        #expect(digest.chosen.isEmpty)
    }

    @Test("an option whose own label carries a comma is read as that option, not as two")
    func optionLabelWithAComma() throws {
        let question = AgentQuestion(
            question: "Should it retry?",
            options: [
                AgentQuestion.Option(label: "Yes, every time"),
                AgentQuestion.Option(label: "No"),
            ],
            answerID: "q3"
        )

        let digest = try #require(
            AgentQuestionDigest.of([question], answers: ["q3": "Yes, every time"]).first
        )

        #expect(digest.answer == .chosen(["Yes, every time"]))
    }

    @Test("a secret answer never reaches the closed line, however it was given")
    func secretAnswer() throws {
        let question = AgentQuestion(
            question: "Which token should it use?", answerID: "q4", isSecret: true
        )

        let digest = try #require(
            AgentQuestionDigest.of([question], answers: ["q4": "sk-live-41"]).first
        )

        #expect(digest.answer == AgentQuestionDigest.Answer.hidden)
        #expect(digest.answerText == AgentQuestionDigest.hiddenText)
        #expect(!digest.answerText.contains("sk-live-41"))
        #expect(!digest.spoken.contains("sk-live-41"))
        #expect(digest.isAnswered)
    }

    @Test("a question whose answer was not kept says so rather than reading as unanswered")
    func answerNobodyKept() throws {
        let digest = try #require(AgentQuestionDigest.of([database], answers: [:]).first)

        #expect(digest.answer == AgentQuestionDigest.Answer.unknown)
        #expect(digest.answerText.isEmpty)
        #expect(!digest.isAnswered)
        #expect(digest.chosen.isEmpty)
    }

    @Test("whitespace is not an answer")
    func blankAnswer() throws {
        let digest = try #require(AgentQuestionDigest.of([database], answers: ["q1": "   "]).first)

        #expect(digest.answer == AgentQuestionDigest.Answer.unknown)
    }

    @Test("a card of several questions closes to one line each, in the order they were asked")
    func severalQuestions() {
        let digests = AgentQuestionDigest.of(
            [database, drivers], answers: ["q1": "SQLite", "q2": "iCloud, Dropbox"]
        )

        #expect(digests.map(\.id) == ["q1", "q2"])
        #expect(digests.map(\.answerText) == ["SQLite", "iCloud, Dropbox"])
    }

    @Test("what VoiceOver reads carries the question and the decision, and names typed words")
    func spoken() {
        let digests = AgentQuestionDigest.of(
            [database, drivers], answers: ["q1": "a managed Postgres", "q2": "iCloud"]
        )

        #expect(digests[0].spoken == "Which database should this use? Answered in your own words: a managed Postgres")
        #expect(digests[1].spoken == "Which drivers should ship? Answered: iCloud")
    }

    @Test("the reopen control says which way it goes")
    func reopenTitle() {
        #expect(AgentQuestionDisclosure.reopenTitle(isOpen: false) == "Show the options again")
        #expect(AgentQuestionDisclosure.reopenTitle(isOpen: true) == "Hide the options")
    }
}
