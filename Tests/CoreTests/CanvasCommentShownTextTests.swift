import Foundation
import Testing
@testable import Core

@Suite("What of a comment the owner reads and the agent gets")
struct CanvasCommentShownTextTests {
    private static func text(_ scalars: UInt32...) -> String {
        var view = String.UnicodeScalarView()
        for value in scalars { view.append(Unicode.Scalar(value)!) }
        return String(view)
    }

    private static let england = text(0x1F3F4, 0xE0067, 0xE0062, 0xE0065, 0xE006E, 0xE0067, 0xE007F)
    private static let scotland = text(0x1F3F4, 0xE0067, 0xE0062, 0xE0073, 0xE0063, 0xE0074, 0xE007F)
    private static let wales = text(0x1F3F4, 0xE0067, 0xE0062, 0xE0077, 0xE006C, 0xE0073, 0xE007F)

    @Test(arguments: [
        text(0x1F469, 0x200D, 0x1F4BB),
        text(0x1F469, 0x1F3FD, 0x200D, 0x1F4BB),
        text(0x1F3F3, 0xFE0F, 0x200D, 0x1F308),
        text(0x1F937, 0x200D, 0x2640, 0xFE0F),
        text(0x1F469, 0x200D, 0x2764, 0xFE0F, 0x200D, 0x1F468),
        text(0x0031, 0xFE0F, 0x20E3),
        text(0x2764, 0xFE0E),
        text(0x1F469, 0x200D, 0x1FAFF),
        england, scotland, wales,
    ])
    func anEmojiSequenceIsLeftExactlyAsItWas(sequence: String) {
        #expect(Array(CanvasCommentFlow.shown(sequence).unicodeScalars) == Array(sequence.unicodeScalars))
    }

    @Test(arguments: [
        text(0x0645, 0x06CC, 0x200C, 0x062E, 0x0648, 0x0627, 0x0647, 0x0645),
        text(0x0915, 0x094D, 0x200D, 0x0937),
        text(0x0995, 0x09CD, 0x200C, 0x09B7),
        text(0x0D28, 0x0D4D, 0x200D, 0x0020, 0x0D15),
        text(0x05E9, 0x05DC, 0x05D5, 0x05DD, 0x200F, 0x0020, 0x0061),
        text(0x0645, 0x0631, 0x062D, 0x0628, 0x0627, 0x200F, 0x0020, 0x0062),
        text(0x0061, 0x200E, 0x0020, 0x05E9),
        text(0x0661, 0x061C, 0x0662),
        text(0x0600, 0x0661, 0x0662),
        text(0x06DD, 0x0661),
        text(0x8FBA, 0xE0100),
        text(0x1820, 0x180B, 0x1821),
        text(0x1820, 0x180E, 0x1821),
        text(0x0065, 0x0301),
        text(0x0378),
        text(0x2800, 0x2801, 0x2800, 0x2800, 0x2802),
        "a\tb\nc",
    ])
    func ordinaryTextInAnyScriptIsLeftExactlyAsItWas(sequence: String) {
        #expect(Array(CanvasCommentFlow.shown(sequence).unicodeScalars) == Array(sequence.unicodeScalars))
    }

    @Test(arguments: [
        0x202A, 0x202B, 0x202C, 0x202D, 0x202E, 0x2066, 0x2067, 0x2068, 0x2069,
        0xE000, 0xF0000, 0x100000,
        0x034F, 0x3164, 0xFFA0, 0x00AD, 0x200B, 0xFEFF, 0x2060, 0xFFF9, 0xFFFB,
        0xE0001, 0xE0041, 0xE007F,
        0x0000, 0x0007, 0x001B, 0x007F, 0x0080, 0x0085, 0x009F,
    ] as [UInt32])
    func aScalarWithNothingToShowGoes(hidden: UInt32) {
        #expect(CanvasCommentFlow.shown(Self.text(0x61, hidden, 0x62)) == "ab")
    }

    @Test(arguments: [0xFE00, 0xFE0E, 0xFE0F, 0xE0100, 0xE01EF, 0x180B] as [UInt32])
    func aVariationSelectorAfterALetterItCannotApplyToGoes(selector: UInt32) {
        #expect(CanvasCommentFlow.shown(Self.text(0x61, selector, 0x62)) == "ab")
    }

    @Test func variationSelectorsCarryingBytesGoEvenAfterACharacterTheyApplyTo() {
        let payload = (0..<64).map { 0xE0100 + UInt32($0) }
        var hidden = "\u{8FBA}"
        for value in payload { hidden.unicodeScalars.append(Unicode.Scalar(value)!) }

        #expect(CanvasCommentFlow.shown(hidden) == Self.text(0x8FBA, 0xE0100))
        #expect(CanvasCommentFlow.shown(Self.text(0x2764, 0xFE0F, 0xFE0F, 0xFE0E)) == Self.text(0x2764, 0xFE0F))
        #expect(CanvasCommentFlow.shown(Self.text(0x2764, 0xE0100)) == Self.text(0x2764))
    }

    @Test func aJoinerBetweenLettersThatDoNotUseItGoes() {
        #expect(CanvasCommentFlow.shown(Self.text(0x61, 0x200D, 0x62)) == "ab")
        #expect(CanvasCommentFlow.shown(Self.text(0x61, 0x200C, 0x62)) == "ab")
        #expect(CanvasCommentFlow.shown(Self.text(0x31, 0x200D, 0x32)) == "12")
        #expect(CanvasCommentFlow.shown(Self.text(0x200D, 0x62)) == "b")
        #expect(CanvasCommentFlow.shown(Self.text(0x1F469, 0x200D)) == Self.text(0x1F469))
        #expect(CanvasCommentFlow.shown(Self.text(0x1F469, 0x200C, 0x1F4BB)) == Self.text(0x1F469, 0x1F4BB))
    }

    @Test func aRunOfJoinersKeepsOnlyTheOneTouchingBothSides() {
        #expect(CanvasCommentFlow.shown(Self.text(0x1F469, 0x200D, 0x200D, 0x200D, 0x1F4BB)) == Self.text(0x1F469, 0x200D, 0x1F4BB))
        #expect(CanvasCommentFlow.shown(Self.text(0x0645, 0x200C, 0x200D, 0x200C, 0x06CC)) == Self.text(0x0645, 0x200C, 0x06CC))
    }

    @Test func aRunOfDirectionMarksKeepsTheFirst() {
        #expect(CanvasCommentFlow.shown(Self.text(0x05E9, 0x200F, 0x200E, 0x200F, 0x061C, 0x200E)) == Self.text(0x05E9, 0x200F))
    }

    @Test func tagsOutsideAValidFlagGo() {
        let hello = Self.text(0x1F3F4, 0xE0068, 0xE0065, 0xE006C, 0xE006C, 0xE006F, 0xE007F)
        #expect(CanvasCommentFlow.shown(hello) == Self.text(0x1F3F4))
        #expect(CanvasCommentFlow.shown(Self.text(0x1F600, 0xE0067, 0xE0062, 0xE0065, 0xE006E, 0xE0067, 0xE007F)) == Self.text(0x1F600))
        #expect(CanvasCommentFlow.shown(Self.text(0x1F3F4, 0xE0067, 0xE0062)) == Self.text(0x1F3F4))
        #expect(CanvasCommentFlow.shown(Self.england + Self.text(0xE0041)) == Self.england)
    }

    @Test func carriageReturnsBecomeTheNewlineTheyWereShownAs() {
        #expect(CanvasCommentFlow.shown("a\r\nb\rc") == "a\nb\nc")
    }

    @Test func whatIsLeftIsAlreadyClean() {
        let alphabet: [UInt32] = [
            0x61, 0x20, 0x0A, 0x31, 0x0645, 0x06CC, 0x0915, 0x094D, 0x8FBA, 0x1820, 0x1F469, 0x1F4BB, 0x1F3F4, 0x2764,
            0x200B, 0x200C, 0x200D, 0x200E, 0x200F, 0x061C, 0x180B, 0x180E, 0x202E, 0xFE0F, 0xFE00, 0xE0100,
            0xE0067, 0xE0062, 0xE0065, 0xE006E, 0xE007F, 0x3164, 0xE000, 0x0D,
        ]
        var state: UInt32 = 390
        for _ in 0..<2_000 {
            var view = String.UnicodeScalarView()
            for _ in 0..<12 {
                state = state &* 1_664_525 &+ 1_013_904_223
                view.append(Unicode.Scalar(alphabet[Int(state >> 16) % alphabet.count])!)
            }
            let once = CanvasCommentFlow.shown(String(view))
            #expect(Array(CanvasCommentFlow.shown(once).unicodeScalars) == Array(once.unicodeScalars))
        }
    }
}
