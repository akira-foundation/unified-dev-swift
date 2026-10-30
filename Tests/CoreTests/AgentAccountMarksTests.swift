import Testing
import Foundation
@testable import Core

@Suite("How long a sign-out mark and a switch mark are believed")
struct AgentAccountMarksTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let work = AccountFixture.work.id
    private let personal = AccountFixture.personal.id

    @Test func aSignOutRightAfterSwitchingToTheAccountIsTheCostOfTryingIt() {
        var marks = AgentAccountMarks()
        marks.noteSwitched(to: work, at: now)
        marks.apply(.signedOut, on: work, at: now.addingTimeInterval(30))
        #expect(marks.cause(for: work) == .afterSwitch)
    }

    @Test func aSignOutExactlyAtTheEdgeOfTheWindowIsStillBlamedOnTheSwitchAndOneSecondLaterIsNot() {
        var edge = AgentAccountMarks()
        edge.noteSwitched(to: work, at: now)
        edge.apply(.signedOut, on: work, at: now.addingTimeInterval(AgentAccountMarks.switchWindow))
        #expect(edge.cause(for: work) == .afterSwitch)
        var past = AgentAccountMarks()
        past.noteSwitched(to: work, at: now)
        past.apply(.signedOut, on: work, at: now.addingTimeInterval(AgentAccountMarks.switchWindow + 1))
        #expect(past.cause(for: work) == .notSignedIn)
    }

    @Test func aSignOutLongAfterTheSwitchIsNotBlamedOnIt() {
        var marks = AgentAccountMarks()
        marks.noteSwitched(to: work, at: now)
        marks.apply(.signedOut, on: work, at: now.addingTimeInterval(AgentAccountMarks.switchWindow + 1))
        #expect(marks.cause(for: work) == .notSignedIn)
    }

    @Test func aSignOutOnAnAccountThatWasNotSwitchedToIsNotBlamedOnTheSwitch() {
        var marks = AgentAccountMarks()
        marks.noteSwitched(to: work, at: now)
        marks.apply(.signedOut, on: personal, at: now)
        #expect(marks.cause(for: personal) == .notSignedIn)
        #expect(marks.cause(for: work) == nil)
    }

    @Test func aTurnThatWorkedClearsTheSignOutAndForgetsTheSwitch() {
        var marks = AgentAccountMarks()
        marks.noteSwitched(to: work, at: now)
        marks.apply(.signedOut, on: work, at: now)
        marks.apply(.working, on: work, at: now.addingTimeInterval(60))
        #expect(marks.cause(for: work) == nil)
        marks.apply(.signedOut, on: work, at: now.addingTimeInterval(120))
        #expect(marks.cause(for: work) == .notSignedIn)
    }

    @Test func aTurnThatWorkedOnAnotherAccountKeepsTheMarkAndTheSwitch() {
        var marks = AgentAccountMarks()
        marks.noteSwitched(to: work, at: now)
        marks.apply(.signedOut, on: work, at: now)
        marks.apply(.working, on: personal, at: now)
        #expect(marks.cause(for: work) == .afterSwitch)
    }

    @Test func choosingAnAccountForgetsTheSwitch() {
        var marks = AgentAccountMarks()
        marks.noteSwitched(to: work, at: now)
        marks.noteChosen()
        marks.apply(.signedOut, on: work, at: now)
        #expect(marks.cause(for: work) == .notSignedIn)
    }

    @Test func observingNothingChangesNothing() {
        var marks = AgentAccountMarks()
        marks.noteSwitched(to: work, at: now)
        let before = marks
        marks.apply(.none, on: work, at: now)
        #expect(marks == before)
    }

    @Test func twoMarksThatDifferOnlyInWhenTheSwitchHappenedAreNotEqual() {
        var first = AgentAccountMarks()
        var second = AgentAccountMarks()
        first.noteSwitched(to: work, at: now)
        second.noteSwitched(to: work, at: now.addingTimeInterval(5))
        #expect(first != second)
    }

    @Test func twoMarksThatDifferOnlyInTheSwitchedAccountAreNotEqual() {
        var first = AgentAccountMarks()
        var second = AgentAccountMarks()
        first.noteSwitched(to: work, at: now)
        second.noteSwitched(to: personal, at: now)
        #expect(first != second)
    }
}
