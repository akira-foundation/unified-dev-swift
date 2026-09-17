import Foundation
import Testing
@testable import Core

@Suite("Search panel nothing")
struct SearchPanelNothingTests {
    private static let all: [SearchPanelNothing] = [
        .nothingYet,
        .noMatch("houdini"),
        .noLiveMatch("houdini", archived: 1),
        .noLiveMatch("houdini", archived: 12),
        .noHiddenMatch("houdini", hidden: 1),
        .noHiddenMatch("houdini", hidden: 13),
        .noCommand("houdini"),
    ]

    private func partsACount(_ message: String) -> Bool {
        let characters = Array(message)
        for (index, character) in characters.enumerated() where character.isNumber {
            guard index + 1 < characters.count else { continue }
            let next = characters[index + 1]
            guard next.isWhitespace else { continue }
            if next != "\u{00A0}" { return true }
        }
        return false
    }

    @Test("no count on the card can be parted from its noun by a line break")
    func countsAreTiedToTheirNouns() {
        for nothing in Self.all {
            #expect(!partsACount(nothing.message), "\(nothing.message)")
        }
    }

    @Test("an ordinary space after a count is what this catches")
    func theCheckCanFail() {
        #expect(partsACount("13 hidden projects are left out."))
        #expect(!partsACount("13\u{00A0}hidden projects are left out."))
    }

    @Test("every case says something, and no two say the same thing")
    func eachCaseSaysItsOwnThing() {
        let messages = Self.all.map(\.message)
        #expect(messages.allSatisfy { !$0.isEmpty })
        #expect(Set(messages).count == messages.count)
        #expect(Self.all.allSatisfy { !$0.title.isEmpty })
    }

    @Test("a sentence about a query quotes it")
    func theQueryIsQuoted() {
        let aboutAQuery: [SearchPanelNothing] = [
            .noMatch("houdini"),
            .noLiveMatch("houdini", archived: 12),
            .noHiddenMatch("houdini", hidden: 13),
            .noCommand("houdini"),
        ]
        for nothing in aboutAQuery {
            #expect(nothing.message.contains("\u{201C}houdini\u{201D}"), "\(nothing.message)")
        }
    }
}
