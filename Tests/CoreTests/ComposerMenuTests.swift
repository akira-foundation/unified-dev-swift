import Testing
import Foundation
@testable import Core

@Suite("Composer menu resolution")
struct ComposerMenuTests {
    @Test("a /word opens the slash menu with the word as the query")
    func slashOpens() throws {
        #expect(ComposerMenu.resolve(draft: "/", caret: 1).slash?.query == "")
        #expect(ComposerMenu.resolve(draft: "/re", caret: 3).slash?.query == "re")
        #expect(ComposerMenu.slashToken(in: "/review-pr", caret: 10)?.query == "review-pr")
    }

    @Test("a slash that begins a word mid sentence opens the menu on that word alone")
    func slashOpensMidSentence() throws {
        let draft = "do a /rev"
        let token = try #require(ComposerMenu.resolve(draft: draft, caret: 9).slash)
        #expect(token.start == 5)
        #expect(token.length == 4)
        #expect(token.query == "rev")
    }

    @Test("a slash glued to the character before it is a path, a URL or a date, not a command")
    func slashNeedsAWordBoundary() {
        #expect(ComposerMenu.resolve(draft: "src/main.swift", caret: 14) == .none)
        #expect(ComposerMenu.resolve(draft: "open src/mai", caret: 12) == .none)
        #expect(ComposerMenu.resolve(draft: "https://x", caret: 9) == .none)
        #expect(ComposerMenu.resolve(draft: "due 23/08", caret: 9) == .none)
        #expect(ComposerMenu.resolve(draft: "and/or", caret: 6) == .none)
        #expect(ComposerMenu.resolve(draft: "(/rev", caret: 5).slash != nil)
    }

    @Test("a space, a newline or a tab after the word closes the slash menu")
    func slashClosesOnWhitespace() {
        #expect(ComposerMenu.slashToken(in: "/review ", caret: 8) == nil)
        #expect(ComposerMenu.slashToken(in: "/review the diff", caret: 16) == nil)
        #expect(ComposerMenu.slashToken(in: "/re\nview", caret: 8) == nil)
        #expect(ComposerMenu.slashToken(in: "/re\tview", caret: 8) == nil)
        #expect(ComposerMenu.slashToken(in: "do a /rev of this", caret: 17) == nil)
    }

    @Test("a draft with no slash before the caret never opens the slash menu")
    func slashNeedsASlash() {
        #expect(ComposerMenu.slashToken(in: "", caret: 0) == nil)
        #expect(ComposerMenu.slashToken(in: "review", caret: 6) == nil)
        #expect(ComposerMenu.slashToken(in: "run /review", caret: 3) == nil)
    }

    @Test("the token is the slash nearest the caret, not the first one in the draft")
    func slashTakesTheNearestSlash() throws {
        let token = try #require(ComposerMenu.slashToken(in: "/review and /re", caret: 15))
        #expect(token.start == 12)
        #expect(token.query == "re")
    }

    @Test("the slash token is measured in UTF-16 units, as the text view counts its caret")
    func slashMeasuresUTF16() throws {
        let draft = "\u{1F642} /rev"
        let caret = (draft as NSString).length
        let token = try #require(ComposerMenu.slashToken(in: draft, caret: caret))
        #expect(token.start == 3)
        #expect(token.length == caret - 3)
    }

    @Test("a command picked on a slash that begins the prompt becomes the chip")
    func pickingAtTheStartMakesAChip() throws {
        let token = try #require(ComposerMenu.slashToken(in: "/rev", caret: 4))
        let insertion = SlashCommandDraft.parse("/rev").picking(command: "review-pr", token: token)
        #expect(insertion.draft.name == "review-pr")
        #expect(insertion.draft.body == "")
        #expect(insertion.draft.text == "/review-pr ")
        #expect(insertion.caret == 0)
    }

    @Test("a slash that is the whole prompt replaces the command already chipped above it")
    func pickingReplacesAnExistingChip() throws {
        let draft = SlashCommandDraft.parse("/review /comp")
        let token = try #require(ComposerMenu.slashToken(in: draft.body, caret: 5))
        let insertion = draft.picking(command: "compact", token: token)

        #expect(insertion.draft.name == "compact")
        #expect(insertion.draft.body == "")
    }

    @Test("a command picked mid sentence replaces the token and nothing either side of it")
    func pickingMidSentenceReplacesTheTokenOnly() throws {
        let draft = "do a /rev of this"
        let token = try #require(ComposerMenu.slashToken(in: draft, caret: 9))
        let insertion = SlashCommandDraft.parse(draft).picking(command: "review-pr", token: token)
        #expect(insertion.draft.name == nil)
        #expect(insertion.draft.text == "do a /review-pr of this")
        #expect(insertion.caret == 16)
        #expect(ComposerMenu.slashToken(in: insertion.draft.body, caret: insertion.caret) == nil)
    }

    @Test("a command picked at the end of a sentence gets the space it needs to be typed after")
    func pickingMidSentenceWritesASpace() throws {
        let draft = "do a /rev"
        let token = try #require(ComposerMenu.slashToken(in: draft, caret: 9))
        let insertion = SlashCommandDraft.parse(draft).picking(command: "review-pr", token: token)
        #expect(insertion.draft.text == "do a /review-pr ")
        #expect(insertion.caret == 16)
    }

    @Test("a command picked in the prompt of a draft that already has a chip leaves the chip")
    func pickingMidSentenceKeepsTheChip() throws {
        let draft = SlashCommandDraft.parse("/review look at /re")
        #expect(draft.name == "review")
        let token = try #require(ComposerMenu.slashToken(in: draft.body, caret: 11))
        let insertion = draft.picking(command: "compact", token: token)
        #expect(insertion.draft.name == "review")
        #expect(insertion.draft.body == "look at /compact ")
    }

    @Test("select all then backspace empties the draft in one edit and every menu dies with it")
    func oneEditEmptiesTheDraft() {
        #expect(ComposerMenu.resolve(draft: "", caret: 0) == .none)
        #expect(ComposerMenu.resolve(draft: "", caret: 10) == .none)
        #expect(ComposerMenu.mentionToken(in: "", caret: 12) == nil)
        #expect(ComposerMenu.slashToken(in: "", caret: 9) == nil)
        let draft = SlashCommandDraft.parse("/review ")
        #expect(draft.name == "review")
        #expect(draft.body.isEmpty)
    }

    @Test("an @ at the caret opens the mention menu with what follows it as the query")
    func mentionOpens() throws {
        let token = try #require(ComposerMenu.resolve(draft: "fix @Sources", caret: 12).mention)
        #expect(token.start == 4)
        #expect(token.length == 8)
        #expect(token.query == "Sources")
    }

    @Test("the token is measured in UTF-16 units, the unit the text view reports its caret in")
    func mentionMeasuresUTF16() throws {
        let draft = "🙂 @Sou"
        let caret = (draft as NSString).length
        let token = try #require(ComposerMenu.resolve(draft: draft, caret: caret).mention)
        #expect(token.start == 3)
        #expect(token.length == caret - 3)
        #expect(token.query == "Sou")
    }

    @Test("an @ in the middle of a word is an email address, not a mention")
    func mentionNeedsABoundary() {
        #expect(ComposerMenu.resolve(draft: "freek@akira-io", caret: 12) == .none)
        #expect(ComposerMenu.resolve(draft: "(@Sources", caret: 9).mention != nil)
        #expect(ComposerMenu.resolve(draft: "[@Sources", caret: 9).mention != nil)
    }

    @Test("whitespace between the @ and the caret closes the mention menu")
    func mentionClosesOnWhitespace() {
        #expect(ComposerMenu.resolve(draft: "@Sources done", caret: 13) == .none)
        #expect(ComposerMenu.resolve(draft: "@Sources\n", caret: 9) == .none)
    }

    @Test("the slash menu outranks a mention in the same draft")
    func slashOutranksMention() {
        #expect(ComposerMenu.resolve(draft: "/re@view", caret: 8).kind == .slash)
    }

    @Test("kind tells the same menu with a longer query apart from a different menu")
    func kindIgnoresTheQuery() {
        #expect(ComposerMenu.resolve(draft: "/r", caret: 2).kind
            == ComposerMenu.resolve(draft: "/re", caret: 3).kind)
        #expect(ComposerMenu.resolve(draft: "/re", caret: 3).kind
            != ComposerMenu.resolve(draft: "@re", caret: 3).kind)
    }
}

@Suite("Menu placement")
struct MenuPlacementTests {
    @Test("a composer with a transcript above it keeps its menu above the box")
    func aboveWhenRoomy() {
        let placement = MenuLayout.placement(above: 600, below: 0)
        #expect(placement == .above(room: 600))
        #expect(placement.menuHeight == MenuLayout.maxHeight)
    }

    @Test("the create window's shape flips the menu below the line being typed")
    func belowWhenTheSheetIsCramped() {
        let placement = MenuLayout.placement(above: 70, below: 170)
        #expect(placement == .below(room: 170))
        #expect(placement.menuHeight == 170)
    }

    @Test("above wins a tie, because flipping for no gain is motion nobody asked for")
    func aboveWinsWhenBelowIsNoBetter() {
        #expect(MenuLayout.placement(above: 70, below: 70) == .above(room: 70))
        #expect(MenuLayout.placement(above: 70, below: 40) == .above(room: 70))
    }

    @Test("enough room above stays above even when below has more")
    func aboveWinsWhenUseful() {
        let placement = MenuLayout.placement(above: MenuLayout.minimumHeight, below: 500)
        #expect(placement == .above(room: MenuLayout.minimumHeight))
    }

    @Test("the menu height never exceeds the cap, whichever side it opens on")
    func menuHeightIsCapped() {
        #expect(MenuLayout.placement(above: 20, below: 900).menuHeight == MenuLayout.maxHeight)
        #expect(MenuLayout.Placement.above(room: 10_000).menuHeight == MenuLayout.maxHeight)
    }

    @Test("negative room is clamped rather than trusted, because geometry arrives mid layout")
    func negativeRoomIsClamped() {
        #expect(MenuLayout.placement(above: -20, below: -20) == .above(room: 0))
        #expect(MenuLayout.placement(above: -20, below: 170) == .below(room: 170))
    }

    @Test("an unmeasured window resolves to the placement every composer had before the choice")
    func infinityMeansAbove() {
        let placement = MenuLayout.placement(above: 600, below: .infinity)
        #expect(placement == .above(room: 600))
    }
}
