import CoreGraphics
import Testing
@testable import Core

@Suite("Search panel layout")
struct SearchPanelLayoutTests {
    @Test("A window at the scene's own default gets a panel wider than the old constant")
    func defaultWindow() {
        let width = SearchPanelLayout.width(inWindow: 1_440)
        #expect(width == 1_440 * SearchPanelLayout.proportion)
        #expect(width > SearchPanelLayout.minimumWidth)
    }

    @Test("A wide window is clamped rather than left to grow")
    func wideWindow() {
        #expect(SearchPanelLayout.width(inWindow: 2_560) == SearchPanelLayout.maximumWidth)
        #expect(SearchPanelLayout.width(inWindow: 3_440) == SearchPanelLayout.maximumWidth)
    }

    @Test("The narrowest window this one can be still gets the width the panel has always had")
    func narrowWindow() {
        #expect(SearchPanelLayout.width(inWindow: 1_122) == SearchPanelLayout.minimumWidth)
        #expect(SearchPanelLayout.width(inWindow: 841) == SearchPanelLayout.minimumWidth)
    }

    @Test("The panel never comes out narrower than it was before it answered the window")
    func neverNarrower() {
        for width in stride(from: CGFloat(0), through: 4_000, by: 20) {
            #expect(SearchPanelLayout.width(inWindow: width) >= SearchPanelLayout.minimumWidth)
        }
    }

    @Test("The panel never comes out wider than the window it is drawn in")
    func neverWiderThanTheWindow() {
        for width in stride(from: CGFloat(841), through: 4_000, by: 20) {
            #expect(SearchPanelLayout.width(inWindow: width) <= width)
        }
    }

    @Test("There is a real margin either side at every width this window can reach")
    func keepsItsMargins() {
        for width in stride(from: CGFloat(841), through: 4_000, by: 20) {
            let panel = SearchPanelLayout.width(inWindow: width)
            #expect((width - panel) / 2 >= SearchPanelLayout.margin)
        }
    }

    private static let grounds: [(name: String, ink: PaletteInk.Pair)] = [
        ("surface", PaletteInk.surface),
        ("surfaceRaised", PaletteInk.surfaceRaised),
        ("surfaceSunken", PaletteInk.surfaceSunken),
    ]

    private func dimmed(_ ground: UInt32, isDark: Bool) -> UInt32 {
        Contrast.composited(0x000000, over: ground, at: SearchPanelLayout.dim(isDark: isDark))
    }

    private func dimmedText(on ground: UInt32, isDark: Bool, at dim: Double? = nil) -> UInt32 {
        let ink: UInt32 = isDark ? 0xFFFFFF : 0x000000
        let label = Contrast.composited(ink, over: ground, at: 0.85)
        return Contrast.composited(
            0x000000, over: label, at: dim ?? SearchPanelLayout.dim(isDark: isDark)
        )
    }

    @Test("no single opacity of black can take the same light out of both grounds")
    func oneNumberCannotServeBothAppearances() {
        let light = PaletteInk.surface.light
        let removed = Contrast.relativeLuminance(of: light)
            - Contrast.relativeLuminance(of: dimmed(light, isDark: false))
        #expect(Contrast.relativeLuminance(of: PaletteInk.surface.dark) < removed)
    }

    @Test("the dark dim is the heaviest one the window behind stays readable under")
    func theDarkDimIsAsHeavyAsItCanBe() {
        for (name, ground) in Self.grounds {
            let ink = ground.dark
            let ratio = Contrast.ratio(dimmedText(on: ink, isDark: true), dimmed(ink, isDark: true))
            #expect(ratio >= Contrast.textFloor, "\(name) at the dark dim reads \(ratio)")
        }

        let worst = PaletteInk.surfaceRaised.dark
        let heavier = SearchPanelLayout.dimDark + 0.05
        let ratio = Contrast.ratio(
            dimmedText(on: worst, isDark: true, at: heavier),
            Contrast.composited(0x000000, over: worst, at: heavier)
        )
        #expect(ratio < Contrast.textFloor)
    }

    @Test("the light dim leaves the window behind well clear of the floor")
    func theLightDimIsUnchanged() {
        #expect(SearchPanelLayout.dimLight == 0.22)
        for (name, ground) in Self.grounds {
            let ink = ground.light
            let ratio = Contrast.ratio(
                dimmedText(on: ink, isDark: false), dimmed(ink, isDark: false)
            )
            #expect(ratio >= Contrast.textFloor, "\(name) at the light dim reads \(ratio)")
        }
    }

    @Test("the dark dim is heavier than the light one and neither blacks the window out")
    func bothEndsAreSane() {
        #expect(SearchPanelLayout.dimDark > SearchPanelLayout.dimLight)
        #expect(SearchPanelLayout.dimLight > 0)
        #expect(SearchPanelLayout.dimDark < 0.6)
        #expect(SearchPanelLayout.dim(isDark: true) == SearchPanelLayout.dimDark)
        #expect(SearchPanelLayout.dim(isDark: false) == SearchPanelLayout.dimLight)
    }

    @Test("The width answers the window and nothing else, so typing cannot move it")
    func onlyTheWindowMovesIt() {
        #expect(SearchPanelLayout.width(inWindow: 1_730) == SearchPanelLayout.width(inWindow: 1_730))
        #expect(SearchPanelLayout.width(inWindow: 1_730) > SearchPanelLayout.width(inWindow: 1_440))
    }
}
