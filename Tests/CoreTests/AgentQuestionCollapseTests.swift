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
        #expect(digest.isAnswered)
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

    @Test("several ticks whose own labels carry commas come back as the ticks, not as prose")
    func multiSelectLabelsWithCommas() throws {
        let question = AgentQuestion(
            question: "When should it retry?",
            multiSelect: true,
            options: [
                AgentQuestion.Option(label: "Yes, every time"),
                AgentQuestion.Option(label: "No"),
                AgentQuestion.Option(label: "Only on a timeout"),
            ],
            answerID: "q5"
        )
        let given = AgentQuestionnaire.joined(["Yes, every time", "No"])

        let digest = try #require(AgentQuestionDigest.of([question], answers: ["q5": given]).first)

        #expect(digest.answer == .chosen(["Yes, every time", "No"]))
        #expect(digest.chosen == ["Yes, every time", "No"])
        #expect(!digest.isTyped)
    }

    @Test("a question that takes one answer never reads two labels as two ticks")
    func singleSelectNeverPicksTwo() throws {
        let digest = try #require(
            AgentQuestionDigest.of([database], answers: ["q1": "SQLite, Postgres"]).first
        )

        #expect(digest.answer == .typed("SQLite, Postgres"))
        #expect(digest.chosen.isEmpty)
    }

    @Test("words of his own that merely start with a label are still his own words")
    func multiSelectTypedAnswer() throws {
        let digest = try #require(
            AgentQuestionDigest.of([drivers], answers: ["q2": "iCloud and nothing else"]).first
        )

        #expect(digest.answer == .typed("iCloud and nothing else"))
        #expect(digest.chosen.isEmpty)
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
        #expect(digest.answerText == "Hidden.")
        #expect(digest.spoken == "Which token should it use? Answered, and the answer is hidden.")
        #expect(!digest.answerText.contains("sk-live-41"))
        #expect(!digest.spoken.contains("sk-live-41"))
        #expect(digest.isAnswered)
        #expect(digest.isTyped)
    }

    @Test("a secret question reads as hidden whatever was recorded in place of the answer")
    func secretAnswerIsHiddenWhateverWasKept() throws {
        let question = AgentQuestion(
            question: "Which token should it use?", answerID: "q4", isSecret: true
        )

        let kept = try #require(
            AgentQuestionDigest.of(
                [question], answers: ["q4": AgentQuestionnaire.hiddenAnswer]
            ).first
        )

        #expect(kept.answer == AgentQuestionDigest.Answer.hidden)
        #expect(kept.answerText == "Hidden.")
        #expect(!kept.answerText.contains(AgentQuestionnaire.hiddenAnswer))
    }

    @Test("a question whose answer was not kept says so rather than reading as unanswered")
    func answerNobodyKept() throws {
        let digest = try #require(AgentQuestionDigest.of([database], answers: [:]).first)

        #expect(digest.answer == AgentQuestionDigest.Answer.unknown)
        #expect(digest.answerText.isEmpty)
        #expect(!digest.isAnswered)
        #expect(!digest.isTyped)
        #expect(digest.chosen.isEmpty)
        #expect(digest.spoken == "Which database should this use? The answer was not kept.")
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

    @Test("a secret answer is never what gets recorded, whichever way it is recorded")
    func secretAnswersAreMasked() {
        let input = JSONValue.parse(Data(#"""
            {"questions":[
              {"question":"Which token?","unifieddevAnswerID":"q1","isSecret":true},
              {"question":"Which host?","unifieddevAnswerID":"q2",
               "options":[{"label":"Herd"}]}]}
            """#.utf8)) ?? .object([:])

        let masked = AgentQuestionnaire.masked(
            ["q1": "sk-live-41", "q2": "Herd"], forQuestionsIn: input
        )

        #expect(masked["q1"] == AgentQuestionnaire.hiddenAnswer)
        #expect(masked["q1"] != "sk-live-41")
        #expect(masked["q2"] == "Herd")
    }

    @Test("the answer a decision carries has already had its secrets taken out of it")
    func decisionMasksItsOwnAnswers() {
        let input = JSONValue.parse(Data(#"""
            {"questions":[{"question":"Which token?","unifieddevAnswerID":"q1","isSecret":true}]}
            """#.utf8)) ?? .object([:])
        let answered = AgentQuestionnaire.answered(input, answers: ["q1": "sk-live-41"])

        #expect(PermissionDecision.answer(input: answered).answers["q1"] == AgentQuestionnaire.hiddenAnswer)
    }

    @Test("the reopen control says which way it goes")
    func reopenTitle() {
        #expect(AgentQuestionDisclosure.reopenTitle(isOpen: false) == "Show the options again")
        #expect(AgentQuestionDisclosure.reopenTitle(isOpen: true) == "Hide the options")
    }
}
