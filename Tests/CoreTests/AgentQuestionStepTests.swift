import Foundation
import Testing
@testable import Core

@Suite("One question at a time")
struct AgentQuestionStepTests {
    private func question(_ id: String, answered: Bool = false) -> AgentQuestion {
        AgentQuestion(question: "Question \(id)?", answerID: id)
    }

    private var three: [AgentQuestion] {
        [question("q1"), question("q2"), question("q3")]
    }

    @Test("a card of one question has no steps to walk")
    func alone() {
        let step = AgentQuestionStep(count: 1)

        #expect(step.isAlone)
        #expect(step.isFirst)
        #expect(step.isLast)
        #expect(step.label == "1 of 1")
    }

    @Test("walking forward stops at the last question rather than running off the end")
    func forward() {
        var step = AgentQuestionStep(count: 3)

        let first = step.advance()
        let second = step.advance()
        let past = step.advance()

        #expect(first)
        #expect(second)
        #expect(!past)
        #expect(step.index == 2)
        #expect(step.isLast)
        #expect(step.label == "3 of 3")
    }

    @Test("walking back stops at the first question")
    func backward() {
        var step = AgentQuestionStep(count: 3, index: 1)

        let back = step.retreat()
        let past = step.retreat()

        #expect(back)
        #expect(!past)
        #expect(step.index == 0)
        #expect(step.isFirst)
    }

    @Test("a step asked for beyond the card is held inside it")
    func held() {
        let beyond = AgentQuestionStep(count: 3, index: 9)
        let before = AgentQuestionStep(count: 3, index: -4)

        #expect(beyond.index == 2)
        #expect(before.index == 0)
    }

    @Test("a card that lost questions underneath holds its step inside what is left")
    func resizing() {
        var step = AgentQuestionStep(count: 5, index: 4)

        step.resize(to: 2)

        #expect(step.count == 2)
        #expect(step.index == 1)
        #expect(step.isLast)
    }

    @Test("a card opens on the first question nobody has answered")
    func opensOnTheFirstGap() {
        let step = AgentQuestionStep.opening(of: three, answers: ["q1": "Yes", "q3": "No"])

        #expect(step.index == 1)
        #expect(step.count == 3)
    }

    @Test("a card answered whole opens at the beginning, because nothing is waiting")
    func opensAtTheStartWhenNothingWaits() {
        let step = AgentQuestionStep.opening(
            of: three, answers: ["q1": "Yes", "q2": "Yes", "q3": "Yes"]
        )

        #expect(step.index == 0)
        #expect(AgentQuestionStep.waiting(in: three, answers: ["q1": "Yes", "q2": "Yes", "q3": "Yes"]).isEmpty)
    }

    @Test("an answer of nothing but spaces leaves its question waiting")
    func blankIsNotAnAnswer() {
        #expect(AgentQuestionStep.waiting(in: three, answers: ["q1": "  "]) == [0, 1, 2])
    }

    @Test("what is still unanswered is said by number, and counted when there is more than one")
    func sayingWhatIsLeft() {
        #expect(
            AgentQuestionStep.stillToAnswer(three, answers: ["q1": "Yes", "q3": "No"])
                == "Question 2 is still unanswered."
        )
        #expect(
            AgentQuestionStep.stillToAnswer(three, answers: ["q2": "Yes"])
                == "2 questions are still unanswered."
        )
        #expect(
            AgentQuestionStep.stillToAnswer(three, answers: ["q1": "a", "q2": "b", "q3": "c"])
                .isEmpty
        )
    }
}
