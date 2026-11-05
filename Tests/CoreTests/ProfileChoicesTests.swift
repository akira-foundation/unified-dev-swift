import Foundation
import Testing
@testable import Core

@Suite("What a profile can look like", .scratchDirectory)
struct ProfileChoicesTests {
    @Test("the symbol grid has symbols and no symbol twice")
    func symbolsAreUnique() {
        let names = ProfileChoices.symbols.map(\.name)
        #expect(!names.isEmpty)
        #expect(Set(names).count == names.count)
    }

    @Test("every symbol has its own spoken label")
    func symbolLabelsAreUnique() {
        let labels = ProfileChoices.symbols.map(\.label)
        #expect(labels.allSatisfy { !$0.isEmpty })
        #expect(Set(labels).count == labels.count)
    }

    @Test("the symbol the first profile starts with can be chosen again")
    func initialSymbolIsInTheGrid() async throws {
        let store = try makeTestStore("profile-choices-initial")
        let initial = try #require(try await store.profile(id: .initial))
        #expect(ProfileChoices.symbols.contains { $0.name == initial.symbol })
    }

    @Test("every colour of the palette has its own spoken name")
    func colourNames() {
        let names = Accent.all.map(ProfileChoices.colourName)
        #expect(names.allSatisfy { !$0.hasPrefix("#") })
        #expect(Set(names).count == Accent.all.count)
    }

    @Test("a colour outside the palette is still named")
    func unknownColour() {
        #expect(ProfileChoices.colourName("123456") == "#123456")
    }
}
