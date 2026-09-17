import Testing
import Foundation
@testable import Core

@Suite("The faces the conversation can be set in")
struct ChatFontCatalogueTests {
    private static let installed = [
        "Charter",
        "Verdana",
        "Helvetica Neue",
        "Avenir Next",
        "Georgia",
        "Palatino",
        "Apple Color Emoji",
        "Apple Symbols",
        "Bodoni Ornaments",
        "Zapf Dingbats",
        "Webdings",
        "Apple Braille",
        "Symbol",
        ".AppleSystemUIFont",
    ]

    private static let installedSet = Set(installed)

    @Test("every value the four-way control wrote still resolves to the same face")
    func theOldValuesStillWork() {
        #expect(ChatFontCatalogue.resolve("system", installed: Self.installedSet) == .system)
        #expect(ChatFontCatalogue.resolve("reading", installed: Self.installedSet) == .serif)
        #expect(ChatFontCatalogue.resolve("book", installed: Self.installedSet) == .family("Charter"))
        #expect(ChatFontCatalogue.resolve("legible", installed: Self.installedSet) == .family("Verdana"))
    }

    @Test("the two old labels canonicalise to the family they named")
    func theOldLabelsBecomeFamilies() {
        #expect(ChatFontCatalogue.canonicalID("book") == "Charter")
        #expect(ChatFontCatalogue.canonicalID("legible") == "Verdana")
        #expect(ChatFontCatalogue.canonicalID("system") == "system")
        #expect(ChatFontCatalogue.canonicalID("reading") == "reading")
    }

    @Test("an old value keeps the name and the sentence the picker showed for it")
    func theOldValuesKeepTheirCopy() {
        #expect(ChatFontCatalogue.recommendation(for: "book")?.title == "Book")
        #expect(ChatFontCatalogue.recommendation(for: "legible")?.title == "Legible")
        #expect(
            ChatFontCatalogue.summary(for: "book", installed: Self.installedSet)
                == ChatFontCatalogue.summary(for: "Charter", installed: Self.installedSet)
        )
        #expect(
            ChatFontCatalogue.summary(for: "system", installed: Self.installedSet)
                .hasPrefix("San Francisco, the face the rest of macOS is set in.")
        )
    }

    @Test("the four head the list, in the order they were offered in")
    func theFourStillHeadTheList() {
        #expect(ChatFontCatalogue.curated.map(\.title) == ["System", "Reading", "Book", "Legible"])
        #expect(ChatFontCatalogue.curated.first?.id == ChatFontCatalogue.standardID)
        #expect(ChatFontCatalogue.curated.allSatisfy { !$0.summary.isEmpty })
    }

    @Test("a family that is installed resolves to itself")
    func anInstalledFamilyResolves() {
        #expect(ChatFontCatalogue.resolve("Palatino", installed: Self.installedSet) == .family("Palatino"))
        #expect(ChatFontCatalogue.recommendation(for: "Palatino") == nil)
        #expect(
            ChatFontCatalogue.summary(for: "Palatino", installed: Self.installedSet)
                == "Palatino, one of the fonts installed on this Mac."
        )
    }

    @Test("a family that is not installed falls back to the system face, and says so")
    func aMissingFamilyFallsBack() {
        #expect(ChatFontCatalogue.resolve("Comic Sans MS", installed: Self.installedSet) == .system)
        #expect(
            ChatFontCatalogue.summary(for: "Comic Sans MS", installed: Self.installedSet)
                .hasPrefix("Comic Sans MS is not installed on this Mac.")
        )
    }

    @Test("a recommendation whose family is gone falls back the same way")
    func aMissingRecommendationFallsBack() {
        let withoutCharter = Self.installedSet.subtracting(["Charter"])
        #expect(ChatFontCatalogue.resolve("book", installed: withoutCharter) == .system)
        #expect(
            ChatFontCatalogue.summary(for: "book", installed: withoutCharter)
                .hasPrefix("Charter is not installed on this Mac.")
        )
        #expect(ChatFontCatalogue.resolve("system", installed: []) == .system)
        #expect(ChatFontCatalogue.resolve("reading", installed: []) == .serif)
    }

    @Test("nothing stored, and nothing but spaces stored, are the standard")
    func anEmptySettingIsTheStandard() {
        #expect(ChatFontCatalogue.canonicalID(nil) == ChatFontCatalogue.standardID)
        #expect(ChatFontCatalogue.canonicalID("") == ChatFontCatalogue.standardID)
        #expect(ChatFontCatalogue.canonicalID("   ") == ChatFontCatalogue.standardID)
        #expect(ChatFontCatalogue.resolve(nil, installed: Self.installedSet) == .system)
        #expect(ChatFontCatalogue.resolve("", installed: Self.installedSet) == .system)
        #expect(ChatFontCatalogue.resolve("  Charter  ", installed: Self.installedSet) == .family("Charter"))
    }

    @Test("the list is sorted, and drops the faces no paragraph is legible in")
    func theListIsWhatCanBeReadIn() {
        let families = ChatFontCatalogue.families(from: Self.installed)
        #expect(families == ["Avenir Next", "Georgia", "Helvetica Neue", "Palatino"])
    }

    @Test("the recommendations are not repeated under themselves")
    func theRecommendationsAppearOnce() {
        let families = ChatFontCatalogue.families(from: Self.installed)
        #expect(!families.contains("Charter"))
        #expect(!families.contains("Verdana"))
    }

    @Test("a duplicate name in the font manager's list is one row")
    func duplicatesCollapse() {
        let families = ChatFontCatalogue.families(from: ["Georgia", "Georgia", " Georgia "])
        #expect(families == ["Georgia"])
    }

    @Test("a selected family that is no longer installed keeps its row")
    func theSelectionSurvivesItsFontGoingMissing() {
        let families = ChatFontCatalogue.families(from: Self.installed, keeping: "Comic Sans MS")
        #expect(families.last == "Comic Sans MS")
        #expect(families.count == 5)
    }

    @Test("a selected recommendation adds nothing to the list under it")
    func aRecommendedSelectionAddsNoRow() {
        let plain = ChatFontCatalogue.families(from: Self.installed)
        #expect(ChatFontCatalogue.families(from: Self.installed, keeping: "book") == plain)
        #expect(ChatFontCatalogue.families(from: Self.installed, keeping: "system") == plain)
        #expect(ChatFontCatalogue.families(from: Self.installed, keeping: "Georgia") == plain)
        #expect(ChatFontCatalogue.families(from: Self.installed, keeping: nil) == plain)
    }

    @Test("the measured x-heights reproduce the constants the four faces carried")
    func theRatioReproducesTheMeasuredConstants() {
        let mono = 6.87451171875
        #expect(ChatFontCatalogue.inlineCodeScale(faceXHeight: 6.8427734375, monoXHeight: mono) == 1)
        #expect(ChatFontCatalogue.inlineCodeScale(faceXHeight: 6.296875, monoXHeight: mono) == 0.92)
        #expect(ChatFontCatalogue.inlineCodeScale(faceXHeight: 6.31591796875, monoXHeight: mono) == 0.92)
        #expect(ChatFontCatalogue.inlineCodeScale(faceXHeight: 7.09033203125, monoXHeight: mono) == 1)
    }

    @Test("code is never set larger than the prose around it, or too small to read")
    func theRatioIsHeldAtBothEnds() {
        #expect(ChatFontCatalogue.inlineCodeScale(faceXHeight: 12, monoXHeight: 6.87) == 1)
        #expect(ChatFontCatalogue.inlineCodeScale(faceXHeight: 2, monoXHeight: 6.87) == 0.8)
        #expect(ChatFontCatalogue.inlineCodeScale(faceXHeight: 0, monoXHeight: 6.87) == 1)
        #expect(ChatFontCatalogue.inlineCodeScale(faceXHeight: 6.87, monoXHeight: 0) == 1)
    }
}
