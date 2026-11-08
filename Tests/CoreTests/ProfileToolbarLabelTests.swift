import CoreGraphics
import Testing
@testable import Core

@Suite("ProfileToolbarLabel")
struct ProfileToolbarLabelTests {
    private func label(drawsSidebar: Bool = true, width: CGFloat) -> ProfileToolbarLabel {
        ProfileToolbarLabel.resolve(profileName: "Akira", drawsSidebar: drawsSidebar, sidebarWidth: width)
    }

    @Test("an open sidebar gives the name what the marks and the toggle leave")
    func openSidebarShowsTheName() {
        #expect(label(width: 260).menuWidth == 108)
        #expect(label(width: 340).menuWidth == 188)
    }

    @Test("a collapsed sidebar shows the mark alone at any width")
    func collapsedShowsTheMark() {
        #expect(label(drawsSidebar: false, width: 340).menuWidth == nil)
        #expect(label(drawsSidebar: false, width: 0).menuWidth == nil)
    }

    @Test("a name is dropped rather than squeezed below what reads as one")
    func tooNarrowDropsTheName() {
        #expect(label(width: 226).menuWidth == 74)
        #expect(label(width: 225).menuWidth == nil)
        #expect(label(width: 200).menuWidth == nil)
        #expect(label(width: 0).menuWidth == nil)
    }

    @Test("a fractional width never hands the name more than fits")
    func fractionalWidthRoundsDown() {
        #expect(label(width: 260.9).menuWidth == 108)
    }

    @Test("the toolbar is told to measure again when the menu's width or name changes, and only then")
    func measureKeyFollowsWhatChangesTheWidth() {
        let resolved = label(width: 260).measureKey
        #expect(label(width: 260).measureKey == resolved)
        #expect(label(width: 261).measureKey != resolved)
        #expect(label(drawsSidebar: false, width: 260).measureKey != resolved)
        #expect(
            ProfileToolbarLabel.resolve(profileName: "Unified", drawsSidebar: true, sidebarWidth: 260).measureKey != resolved
        )
        #expect(label(width: 0).measureKey == label(drawsSidebar: false, width: 260).measureKey)
    }

    @Test("help and accessibility carry the whole name, whatever is drawn")
    func fullNameIsAlwaysSaid() {
        let long = "A client whose name goes on far longer than any sidebar is wide"
        for drawsSidebar in [true, false] {
            let resolved = ProfileToolbarLabel.resolve(profileName: long, drawsSidebar: drawsSidebar, sidebarWidth: 260)
            #expect(resolved.help == "Switch profile, \(long)")
            #expect(resolved.accessibilityLabel == "Profile, \(long)")
        }
    }
}
