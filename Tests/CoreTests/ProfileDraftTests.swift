import Foundation
import Testing
@testable import Core

@Suite("Filling in a profile")
struct ProfileDraftTests {
    private func profile(_ name: String, colour: String, symbol: String) -> Profile {
        Profile(id: ProfileID(name), name: name, folder: name, colour: colour, symbol: symbol)
    }

    @Test("a name of nothing, or only of spaces, cannot be saved", arguments: ["", "   ", "\n\t "])
    func blankName(name: String) {
        var draft = ProfileDraft.new(among: [])
        draft.name = name
        #expect(!draft.canSave)
        #expect(draft.nameProblem == ProfileDraft.nameRequired)
    }

    @Test("a name with something in it can be saved, without the spaces around it")
    func trimmedName() {
        var draft = ProfileDraft.new(among: [])
        draft.name = "  Akira  "
        #expect(draft.canSave)
        #expect(draft.nameProblem == nil)
        #expect(draft.savedName == "Akira")
    }

    @Test("a new profile starts blank, on a colour and a symbol nobody else has")
    func newDraftAvoidsTaken() {
        let taken = profile("Unified", colour: Accent.all[0], symbol: ProfileChoices.symbols[0].name)
        let draft = ProfileDraft.new(among: [taken])
        #expect(draft.name.isEmpty)
        #expect(draft.colour == Accent.all[1])
        #expect(draft.symbol == ProfileChoices.symbols[1].name)
    }

    @Test("a new profile still has a colour and a symbol when every one is taken")
    func newDraftWhenAllTaken() {
        let everyone = Accent.all.enumerated().map { index, colour in
            profile("p\(index)", colour: colour, symbol: "x")
        }
        let symbols = ProfileChoices.symbols.map { profile($0.name, colour: "000000", symbol: $0.name) }
        let draft = ProfileDraft.new(among: everyone + symbols)
        #expect(Accent.all.contains(draft.colour))
        #expect(ProfileChoices.symbols.contains { $0.name == draft.symbol })
    }

    @Test("editing starts from what the profile already has")
    func editingDraft() {
        let draft = ProfileDraft(editing: profile("Akira", colour: Accent.all[3], symbol: "leaf"), accounts: .own)
        #expect(draft.name == "Akira")
        #expect(draft.colour == Accent.all[3])
        #expect(draft.symbol == "leaf")
    }
}
