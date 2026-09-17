import Testing
import Foundation
@testable import Core

@Suite("What a table compares to know a row's content moved")
struct TranscriptContentKeyTests {
    @Test("the same fields are the same key")
    func isStableForTheSameFields() {
        let one = TranscriptContentKey {
            $0.combine(7)
            $0.combine("assistantText")
            $0.combine(false)
        }
        let other = TranscriptContentKey {
            $0.combine(7)
            $0.combine("assistantText")
            $0.combine(false)
        }
        #expect(one == other)
    }

    @Test("one field moving is a different key")
    func oneFieldIsEnough() {
        let folded = TranscriptContentKey {
            $0.combine(7)
            $0.combine(false)
        }
        let unfolded = TranscriptContentKey {
            $0.combine(7)
            $0.combine(true)
        }
        #expect(folded != unfolded)
    }

    @Test("two fields cannot be spelled into each other")
    func doesNotRunFieldsTogether() {
        let one = TranscriptContentKey {
            $0.combine("row")
            $0.combine("12")
        }
        let other = TranscriptContentKey {
            $0.combine("row1")
            $0.combine("2")
        }
        #expect(one != other)
    }

    @Test("a key is a dictionary key")
    func worksAsADictionaryKey() {
        let seven = TranscriptContentKey { $0.combine("row.7") }
        let sevenAgain = TranscriptContentKey { $0.combine("row.7") }
        let eight = TranscriptContentKey { $0.combine("row.8") }
        var heights: [TranscriptContentKey: Double] = [:]
        heights[seven] = 120
        #expect(heights[sevenAgain] == 120)
        #expect(heights[eight] == nil)
    }
}
