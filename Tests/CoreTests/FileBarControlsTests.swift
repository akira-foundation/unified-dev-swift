import Testing
import Foundation
@testable import Core

@Suite("The controls above a file")
struct FileBarControlsTests {
    private var all: [FileBarControl] {
        [
            FileBarControls.revert(filename: "Handler.php"),
            FileBarControls.layout,
            FileBarControls.whitespace(ignoring: false),
            FileBarControls.whitespace(ignoring: true),
            FileBarControls.copy(mode: .diff),
            FileBarControls.copy(mode: .edit),
            FileBarControls.copy(mode: .diff, didCopy: true),
            FileBarControls.more,
            FileBarControls.mode(filename: "Handler.php", isEditable: true),
            FileBarControls.mode(filename: "Handler.php", isEditable: false),
        ]
    }

    @Test("every control has a word and a sentence")
    func nothingIsBlank() {
        for control in all {
            #expect(!control.title.isEmpty)
            #expect(!control.hint.isEmpty)
        }
    }

    @Test("the word is a word and the sentence is longer than it")
    func aTitleIsShortAndAHintExplains() {
        for control in all {
            #expect(control.title.count <= 20)
            #expect(control.hint.count > control.title.count)
        }
    }

    @Test("nothing is titled with a sentence and nothing is hinted with a fragment")
    func theRegisterIsRight() {
        for control in all {
            #expect(!control.title.hasSuffix("."))
            #expect(!control.hint.hasSuffix("."))
            #expect(control.title.first?.isUppercase == true)
            #expect(control.hint.first?.isUppercase == true)
        }
    }

    @Test("revert names the file it would throw away")
    func revertNamesTheFile() {
        let control = FileBarControls.revert(filename: "Handler.php")

        #expect(control.title == "Revert file")
        #expect(control.hint.contains("Handler.php"))
    }

    @Test("copy says which of the two panes it would copy")
    func copyFollowsTheModeItIsIn() {
        #expect(FileBarControls.copy(mode: .diff).title == "Copy diff")
        #expect(FileBarControls.copy(mode: .edit).title == "Copy file")
        #expect(FileBarControls.copy(mode: .diff).hint.contains("diff"))
        #expect(FileBarControls.copy(mode: .edit).hint.contains("file"))
    }

    @Test("the flash after a press changes the sentence and never the word")
    func copyKeepsItsWidthWhileItFlashes() {
        for mode in FileViewMode.allCases {
            let resting = FileBarControls.copy(mode: mode)
            let flashed = FileBarControls.copy(mode: mode, didCopy: true)

            #expect(flashed.title == resting.title)
            #expect(flashed.hint != resting.hint)
            #expect(flashed.hint.contains("clipboard"))
        }
    }

    @Test("the whitespace toggle says what pressing it will do, not what state it is in")
    func whitespaceSaysWhatWillHappen() {
        let hiding = FileBarControls.whitespace(ignoring: true)
        let showing = FileBarControls.whitespace(ignoring: false)

        #expect(hiding.title == showing.title)
        #expect(hiding.hint != showing.hint)
        #expect(showing.hint.hasPrefix("Hide"))
        #expect(hiding.hint.hasPrefix("Show"))
    }

    @Test("a file that cannot be edited says so instead of describing the switch")
    func theModePickerAnswersWhyItIsOff() {
        let editable = FileBarControls.mode(filename: "logo.png", isEditable: true)
        let locked = FileBarControls.mode(filename: "logo.png", isEditable: false)

        #expect(locked.hint == "logo.png cannot be edited here")
        #expect(editable.hint != locked.hint)
        #expect(editable.hint.contains("logo.png"))
    }

    @Test("the two layout segments are the words the overflow menu uses")
    func oneSpellingOfOneChoice() {
        #expect(FileBarControls.unified == "Unified")
        #expect(FileBarControls.sideBySide == "Side by side")
        #expect(FileBarControls.unified != FileBarControls.sideBySide)
    }
}
