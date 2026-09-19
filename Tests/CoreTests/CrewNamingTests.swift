import Testing
@testable import Core

@Suite("Naming the subagent a card starts here")
struct CrewNamingTests {
    @Test("a title nobody is using is the name")
    func free() {
        #expect(CrewNaming.free(for: "Keep the last row", existing: ["tests"]) == "Keep the last row")
    }

    @Test("a title already taken gets the next free number")
    func numbered() {
        #expect(CrewNaming.free(for: "Keep the last row", existing: ["Keep the last row"]) == "Keep the last row 2")
        #expect(
            CrewNaming.free(for: "Keep the last row", existing: ["Keep the last row", "Keep the last row 2"])
                == "Keep the last row 3"
        )
    }

    @Test("a long title stays inside the name limit, number and all")
    func long() {
        let title = String(repeating: "abcdefghij", count: 4)
        let first = CrewNaming.free(for: title, existing: [])

        let second = CrewNaming.free(for: title, existing: [first])

        #expect(first.count == Crew.nameLimit)
        #expect(second.count <= Crew.nameLimit)
        #expect(second.hasSuffix(" 2"))
    }

    @Test("a blank title falls back to a plain name")
    func blank() {
        #expect(CrewNaming.free(for: "   ", existing: []) == CrewNaming.fallback)
    }
}
