import Testing
import Foundation
@testable import Core

@Suite("How a notice is toned")
struct NoticeToneTests {
    @Test("a notice is information unless it says otherwise")
    func defaultTone() {
        #expect(Notice(message: "Renamed.").tone == .information)
        #expect(Notice(message: "Could not save.", tone: .error).tone == .error)
    }

    @Test("each tone draws its own symbol")
    func symbols() {
        #expect(NoticeTone.information.symbol == "info.circle.fill")
        #expect(NoticeTone.warning.symbol == "exclamationmark.triangle.fill")
        #expect(NoticeTone.error.symbol == "xmark.octagon.fill")
        #expect(Set(NoticeTone.allCases.map(\.symbol)).count == NoticeTone.allCases.count)
    }

    @Test("warning and error keep their meaning and never take the accent")
    func semanticInk() {
        #expect(NoticeTone.warning.ink == .meaning(.warning))
        #expect(NoticeTone.error.ink == .meaning(.negative))
    }

    @Test("information takes the accent, stepping aside from warning and negative")
    func informationInk() {
        #expect(NoticeTone.information.ink == .accent(beside: [.warning, .negative]))
    }

    @Test("an Orange or Red system accent steps aside next to a notice", arguments: [false, true])
    func collidingAccents(isDark: Bool) {
        let orange = AccentInk(accent: PaletteInk.warning.member(dark: isDark), isDark: isDark)
        let red = AccentInk(accent: PaletteInk.negative.member(dark: isDark), isDark: isDark)
        #expect(orange.stepsAside(beside: NoticeTone.meaningsBesideAccent))
        #expect(red.stepsAside(beside: NoticeTone.meaningsBesideAccent))
    }

    @Test("VoiceOver hears the tone before the words, and nothing for plain information")
    func spoken() {
        #expect(Notice(message: "Renamed. It was taken.").spoken == "Renamed. It was taken.")
        #expect(Notice(message: "Could not save.", tone: .error).spoken == "Error. Could not save.")
        #expect(NoticeTone.warning.spoken("Skipped", " ", "Open the file.") == "Warning. Skipped. Open the file.")
    }

    @Test("the test notice walks through every tone and comes back")
    func cycle() {
        #expect(NoticeTone.information.next == .warning)
        #expect(NoticeTone.warning.next == .error)
        #expect(NoticeTone.error.next == .information)
        for tone in NoticeTone.allCases {
            #expect(Notice.sample(tone).tone == tone)
            #expect(Notice.sample(tone).lifetime != nil)
        }
    }
}

@Suite("Where a passing notice appears")
struct NoticePlacementTests {
    @Test("top centre is the default, and an unknown stored value falls back to it")
    func standard() {
        #expect(NoticePlacement.standard == .topCentre)
        #expect(NoticePlacement(stored: nil) == .topCentre)
        #expect(NoticePlacement(stored: "somewhere") == .topCentre)
        #expect(NoticePlacement(stored: "topTrailing") == .topTrailing)
        #expect(NoticePlacement(stored: NoticePlacement.aboveComposer.rawValue) == .aboveComposer)
    }

    @Test("a notice slides in from the side it sits on")
    func entrance() {
        #expect(NoticePlacement.topCentre.entrance == .top)
        #expect(NoticePlacement.topTrailing.entrance == .trailing)
        #expect(NoticePlacement.aboveComposer.entrance == .bottom)
    }

    @Test("only the bottom position keeps clear of the composer")
    func clears() {
        #expect(NoticePlacement.allCases.filter(\.clearsComposer) == [.aboveComposer])
    }

    @Test("the notice sits above the tallest composer in the column")
    func clearance() {
        #expect(NoticePlacement.composerClearance(composerTops: [], columnHeight: 800) == 0)
        #expect(NoticePlacement.composerClearance(composerTops: [680], columnHeight: 800) == 120)
        #expect(NoticePlacement.composerClearance(composerTops: [680, 610], columnHeight: 800) == 190)
    }

    @Test("a composer measured outside the column never pushes the notice out of it")
    func clamped() {
        #expect(NoticePlacement.composerClearance(composerTops: [820], columnHeight: 800) == 0)
        #expect(NoticePlacement.composerClearance(composerTops: [-40], columnHeight: 800) == 800)
    }

    @Test("every position has a title for Settings")
    func titles() {
        #expect(NoticePlacement.allCases.map(\.title) == ["Top centre", "Top right", "Bottom, above the composer"])
    }
}
