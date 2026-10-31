import Foundation
import Testing
@testable import Core

@Suite("Agent question drafts")
struct AgentQuestionDraftTests {
    private let single = AgentQuestion(
        question: "Which database should this use?",
        options: [
            AgentQuestion.Option(label: "SQLite"),
            AgentQuestion.Option(label: "Postgres"),
        ]
    )

    private let multi = AgentQuestion(
        question: "Which checks should run?",
        multiSelect: true,
        options: [
            AgentQuestion.Option(label: "Build"),
            AgentQuestion.Option(label: "Lint"),
            AgentQuestion.Option(label: "Tests"),
        ]
    )

    @Test("ticking a single-select question replaces, and ticking the same option again clears it")
    func singleSelectReplaces() {
        var draft = AgentQuestionDraft()

        draft.toggle("SQLite", on: single)
        #expect(draft.chosen[single.id] == ["SQLite"])

        draft.toggle("Postgres", on: single)
        #expect(draft.chosen[single.id] == ["Postgres"])

        draft.toggle("Postgres", on: single)
        #expect(draft.chosen[single.id] == [])
    }

    @Test("ticking a multi-select question accumulates, and ticking again removes just that one")
    func multiSelectAccumulates() {
        var draft = AgentQuestionDraft()

        draft.toggle("Build", on: multi)
        draft.toggle("Tests", on: multi)
        #expect(draft.chosen[multi.id] == ["Build", "Tests"])

        draft.toggle("Build", on: multi)
        #expect(draft.chosen[multi.id] == ["Tests"])
    }

    @Test("ticking an option puts the typed words away, so the two are never sent joined together")
    func tickingClearsTypedWords() {
        var draft = AgentQuestionDraft()

        draft.writeOther(on: single)
        draft.other[single.id] = "Neither, use a file"

        draft.toggle("SQLite", on: single)

        #expect(draft.other[single.id] == "")
        #expect(!draft.isWritingOther.contains(single.id))
        #expect(draft.answers(to: [single]) == [single.id: "SQLite"])
    }

    @Test("opening the Other row clears whatever was ticked on that question")
    func otherRowClearsTicks() {
        var draft = AgentQuestionDraft()

        draft.toggle("Lint", on: multi)
        draft.toggle("Tests", on: multi)

        draft.writeOther(on: multi)

        #expect(draft.chosen[multi.id] == [])
        #expect(draft.isWritingOther.contains(multi.id))
    }

    @Test("typed words win over ticks that are still on the question")
    func typedWordsWin() {
        var draft = AgentQuestionDraft()

        draft.chosen[single.id] = ["SQLite"]
        draft.other[single.id] = "Neither, use a flat file"

        #expect(draft.answers(to: [single]) == [single.id: "Neither, use a flat file"])
    }

    @Test("an Other row holding nothing but spaces answers nothing")
    func blankOtherAnswersNothing() {
        var draft = AgentQuestionDraft()

        draft.writeOther(on: single)
        draft.other[single.id] = "   \n "

        #expect(draft.answers(to: [single]).isEmpty)
        #expect(!draft.isComplete([single]))
    }

    @Test("several ticks are joined in the order the asker offered them, not the order tapped")
    func answersKeepTheAskersOrder() {
        var draft = AgentQuestionDraft()

        draft.toggle("Tests", on: multi)
        draft.toggle("Build", on: multi)
        draft.toggle("Lint", on: multi)

        #expect(draft.answers(to: [multi]) == [multi.id: "Build, Lint, Tests"])
    }

    @Test("a question with nothing on it is left out of the answers rather than answered emptily")
    func untouchedQuestionsAreLeftOut() {
        var draft = AgentQuestionDraft()

        draft.toggle("SQLite", on: single)

        #expect(draft.answers(to: [single, multi]) == [single.id: "SQLite"])
    }

    @Test("a card is complete only once every one of its questions has something to send")
    func completenessAcrossSeveralQuestions() {
        var draft = AgentQuestionDraft()

        #expect(!draft.isComplete([single, multi]))

        draft.toggle("SQLite", on: single)
        #expect(!draft.isComplete([single, multi]))
        #expect(draft.isComplete([single]))

        draft.writeOther(on: multi)
        draft.other[multi.id] = "Only the ones that changed"
        #expect(draft.isComplete([single, multi]))
    }

    @Test("no questions at all is not complete, whatever the draft holds")
    func noQuestionsIsNotComplete() {
        var draft = AgentQuestionDraft()

        draft.toggle("SQLite", on: single)

        #expect(!draft.isComplete([]))
    }

    @Test("the question walked to stays shown, whichever question is still waiting")
    func walkedStepOutlivesTheAnswers() {
        let questions = [single, multi]
        var draft = AgentQuestionDraft()

        draft.toggle("SQLite", on: single)
        draft.walked = 0
        let back = draft.step(through: questions, given: draft.answers(to: questions))

        draft.walked = 1
        draft.toggle("Lint", on: multi)
        let forward = draft.step(through: questions, given: draft.answers(to: questions))

        #expect(back.index == 0)
        #expect(forward.index == 1)
    }

    @Test("with nothing walked, the step opens on the first question still waiting")
    func unwalkedStepOpensOnTheFirstWaiting() {
        let questions = [single, multi]
        var draft = AgentQuestionDraft()

        draft.toggle("Lint", on: multi)
        let first = draft.step(through: questions, given: draft.answers(to: questions))

        draft.toggle("Lint", on: multi)
        draft.toggle("SQLite", on: single)
        let second = draft.step(through: questions, given: draft.answers(to: questions))

        #expect(first.index == 0)
        #expect(second.index == 1)
    }

    @Test("a walked step past the last question is held on the last one")
    func walkedStepIsHeldWithinTheQuestions() {
        let questions = [single, multi]
        var draft = AgentQuestionDraft()

        draft.walked = 9

        let step = draft.step(through: questions, given: [:])
        #expect(step.index == 1)
        #expect(step.count == 2)
    }

    @Test("choosing on a single-select question moves on to the next one")
    func choosingOneMovesOn() {
        let questions = [single, multi]
        var draft = AgentQuestionDraft()

        draft.choose("SQLite", on: single, at: step(of: draft, through: questions))

        #expect(step(of: draft, through: questions).index == 1)
    }

    @Test("choosing on a multi-select question stays on it, so more can be ticked")
    func choosingManyStays() {
        let questions = [multi, single]
        var draft = AgentQuestionDraft()

        draft.choose("Build", on: multi, at: step(of: draft, through: questions))

        #expect(step(of: draft, through: questions).index == 0)
    }

    @Test("choosing on the last question stays on it rather than going back to the first")
    func choosingOnTheLastStays() {
        let questions = [multi, single]
        var draft = AgentQuestionDraft()

        draft.choose("Build", on: multi, at: step(of: draft, through: questions))
        draft.walked = 1
        draft.choose("Postgres", on: single, at: step(of: draft, through: questions))

        #expect(draft.walked == 1)
    }

    @Test("choosing on a middle question moves on to the one after it")
    func choosingInTheMiddleMovesOn() {
        let last = AgentQuestion(
            question: "Where should the export go?",
            options: [AgentQuestion.Option(label: "Disk"), AgentQuestion.Option(label: "Bucket")]
        )
        let questions = [multi, single, last]
        var draft = AgentQuestionDraft()

        draft.walked = 1
        draft.choose("SQLite", on: single, at: step(of: draft, through: questions))

        #expect(draft.walked == 2)
    }

    @Test("holding a question never moves a step that was already walked")
    func holdingLeavesAWalkedStep() {
        var draft = AgentQuestionDraft()

        draft.walked = 1
        draft.hold(AgentQuestionStep(count: 2, index: 0))

        #expect(draft.walked == 1)
    }

    @Test("clearing a single-select choice stays on the question")
    func clearingStays() {
        let questions = [single, multi]
        var draft = AgentQuestionDraft()

        draft.choose("SQLite", on: single, at: step(of: draft, through: questions))
        draft.walked = 0
        draft.choose("SQLite", on: single, at: step(of: draft, through: questions))

        #expect(step(of: draft, through: questions).index == 0)
    }

    @Test("writing an answer of one's own holds the question shown")
    func holdingKeepsTheShownQuestion() {
        let questions = [single, multi]
        var draft = AgentQuestionDraft()

        draft.hold(step(of: draft, through: questions))
        draft.other[single.id] = "A flat file"

        #expect(step(of: draft, through: questions).index == 0)
    }

    private func step(of draft: AgentQuestionDraft, through questions: [AgentQuestion]) -> AgentQuestionStep {
        draft.step(through: questions, given: draft.answers(to: questions))
    }
}
