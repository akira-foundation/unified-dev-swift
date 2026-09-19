import Foundation
import Testing
@testable import Core

extension PaletteContrastTests {
    struct Swatch: CustomTestStringConvertible, Sendable {
        let name: String
        let light: UInt32
        let dark: UInt32

        var testDescription: String { name }

        func ink(dark isDark: Bool) -> AccentInk {
            AccentInk(accent: isDark ? dark : light, isDark: isDark)
        }
    }

    static let multicolor = Swatch(
        name: "multicolor", light: PaletteInk.multicolorAccent.light, dark: PaletteInk.multicolorAccent.dark
    )
    static let blue = Swatch(name: "blue", light: 0x007AFF, dark: 0x007AFF)
    static let purple = Swatch(name: "purple", light: 0x953D96, dark: 0xA550A7)
    static let pink = Swatch(name: "pink", light: 0xF74F9E, dark: 0xF74F9E)
    static let red = Swatch(name: "red", light: 0xE0383E, dark: 0xFF5257)
    static let orange = Swatch(name: "orange", light: 0xF7821B, dark: 0xF7821B)
    static let yellow = Swatch(name: "yellow", light: 0xFFC726, dark: 0xFFC600)
    static let green = Swatch(name: "green", light: 0x62BA46, dark: 0x62BA46)
    static let graphite = Swatch(name: "graphite", light: 0x989898, dark: 0x8C8C8C)

    static let systemAccents = [blue, purple, pink, red, orange, yellow, green, graphite]
    static let everyAccent = [multicolor] + systemAccents

    private static let accentGrounds = [PaletteInk.surface, PaletteInk.surfaceRaised, PaletteInk.surfaceSunken]

    private static func floor(for swatch: Swatch) -> Double {
        swatch.name == "graphite" ? 7.0 : 4.5
    }

    @Test("the accent ink clears its text floor on every ground, for every accent", arguments: everyAccent)
    func accentInkClearsItsFloor(swatch: Swatch) {
        for isDark in [false, true] {
            let accent = swatch.ink(dark: isDark)
            for ground in Self.accentGrounds {
                let ratio = Contrast.ratio(accent.ink, ground.member(dark: isDark))
                #expect(
                    ratio >= Self.floor(for: swatch),
                    "\(swatch.name) ink, \(isDark ? "dark" : "light"): \(ratio) to 1"
                )
            }
        }
    }

    @Test("an accent that already clears the floor is drawn as itself", arguments: everyAccent)
    func aReadableAccentIsLeftAlone(swatch: Swatch) {
        for isDark in [false, true] {
            let accent = swatch.ink(dark: isDark)
            let clears = Self.accentGrounds.allSatisfy {
                Contrast.ratio(accent.accent, $0.member(dark: isDark)) >= Self.floor(for: swatch)
            }
            #expect(clears == (accent.ink == accent.accent), "\(swatch.name), \(isDark ? "dark" : "light")")
        }
    }

    @Test("a mixed ink stops close to its floor and keeps the accent's hue", arguments: everyAccent)
    func theMixIsTheSmallestThatClears(swatch: Swatch) {
        for isDark in [false, true] {
            let accent = swatch.ink(dark: isDark)
            guard accent.ink != accent.accent else { continue }
            let ratio = Contrast.ratio(accent.ink, PaletteInk.surface.member(dark: isDark))
            #expect(ratio < Self.floor(for: swatch) + 0.5, "\(swatch.name), \(isDark ? "dark" : "light"): \(ratio) to 1")
            #expect(accent.ink != (isDark ? 0xFFFFFF : 0x000000), "\(swatch.name) was mixed all the way")
        }
    }

    @Test("four system accents fall under the mark floor on the light surface, and this is that measurement")
    func theFillIsTheSystemsOwnColour() {
        var dim: Set<String> = []
        for swatch in Self.everyAccent {
            let light = swatch.ink(dark: false)
            #expect(light.fill == swatch.light)
            if Contrast.ratio(light.fill, PaletteInk.surface.light) < Contrast.nonTextFloor { dim.insert(swatch.name) }
            let dark = swatch.ink(dark: true)
            let onDark = Contrast.ratio(dark.fill, PaletteInk.surfaceRaised.dark)
            #expect(onDark >= Contrast.nonTextFloor, "\(swatch.name) fill on the dark raised surface: \(onDark) to 1")
        }
        #expect(dim == ["orange", "yellow", "green", "graphite"])
    }

    @Test("an accent read from its sRGB components packs into the same hex")
    func componentsPackIntoHex() {
        #expect(AccentInk(red: 1, green: 0.78, blue: 0.15, isDark: false).accent == 0xFFC726)
        #expect(AccentInk(red: 0, green: 0x7A / 255.0, blue: 1, isDark: true).accent == 0x007AFF)
        #expect(AccentInk(red: -0.1, green: 1.2, blue: 0.5, isDark: false).accent == 0x00FF80)
    }

    @Test("every meaning names its own palette pair")
    func meaningsAreTheirPairs() {
        #expect(PaletteMeaning.warning.ink == PaletteInk.warning)
        #expect(PaletteMeaning.negative.ink == PaletteInk.negative)
        #expect(PaletteMeaning.positive.ink == PaletteInk.positive)
        #expect(PaletteMeaning.running.ink == PaletteInk.running)
        #expect(PaletteMeaning.merged.ink == PaletteInk.merged)
    }

    @Test("on Multicolor a status beside running keeps its violet, since running has a hue of its own")
    func multicolorKeepsItsHueBesideRunning() {
        for isDark in [false, true] {
            #expect(!Self.multicolor.ink(dark: isDark).collides(with: .running))
            #expect(!Self.multicolor.ink(dark: isDark).stepsAside(beside: PaletteMeaning.allCases))
            #expect(!Self.purple.ink(dark: isDark).stepsAside(beside: PaletteMeaning.allCases))
        }
    }

    @Test("running reads apart from every notice tone, whatever the accent", arguments: everyAccent)
    func runningIsNoNoticeTone(swatch: Swatch) {
        for isDark in [false, true] {
            let accent = swatch.ink(dark: isDark)
            let running = PaletteInk.running.member(dark: isDark)
            for tone in NoticeTone.allCases {
                let drawn: [UInt32] = switch tone.ink {
                case .accent: [accent.fill, accent.ink]
                case .meaning(let meaning): [meaning.ink.member(dark: isDark)]
                }
                for colour in drawn {
                    let measured = Contrast.deltaE(running, colour)
                    #expect(
                        measured >= AccentInk.collisionDistance,
                        "running against the \(tone) notice on \(swatch.name), \(isDark ? "dark" : "light"): \(measured)"
                    )
                }
            }
        }
    }

    @Test("the text on an accent fill clears the large text floor, for every accent", arguments: everyAccent)
    func textOnTheFillIsReadable(swatch: Swatch) {
        for isDark in [false, true] {
            let accent = swatch.ink(dark: isDark)
            let ratio = Contrast.ratio(accent.onFill, accent.fill)
            #expect(
                ratio >= Contrast.largeTextFloor,
                "\(swatch.name) label, \(isDark ? "dark" : "light"): \(ratio) to 1"
            )
        }
    }

    @Test("a yellow accent takes dark text, and the coloured accents that carry white keep it")
    func textOnTheFillIsChosenByContrast() {
        for isDark in [false, true] {
            #expect(Self.yellow.ink(dark: isDark).onFill == 0x000000)
            #expect(Self.orange.ink(dark: isDark).onFill == 0x000000)
            for swatch in [Self.multicolor, Self.blue, Self.purple, Self.pink, Self.red] {
                #expect(swatch.ink(dark: isDark).onFill == 0xFFFFFF, "\(swatch.name)")
            }
        }
    }

    @Test("graphite is the only accent with no hue, and is held to the enhanced floor")
    func graphiteIsHandledOnPurpose() {
        for swatch in Self.everyAccent {
            #expect(swatch.ink(dark: false).isAchromatic == (swatch.name == "graphite"), "\(swatch.name)")
        }
        for isDark in [false, true] {
            let graphite = Self.graphite.ink(dark: isDark)
            #expect(graphite.textFloor == 7.0)
            #expect(graphite.ink != graphite.accent)
            #expect(graphite.onFill == 0x000000)
        }
        let dark = Self.graphite.ink(dark: true)
        let onDark = Contrast.ratio(dark.ink, PaletteInk.surface.dark)
        #expect(onDark >= AccentInk.enhancedTextFloor, "graphite ink on dark: \(onDark) to 1")
    }

    @Test("orange steps aside for warning and red for negative, in both appearances")
    func theNamedCollisions() {
        for isDark in [false, true] {
            let orange = Self.orange.ink(dark: isDark)
            let red = Self.red.ink(dark: isDark)
            #expect(orange.collides(with: .warning))
            #expect(!orange.collides(with: .negative))
            #expect(red.collides(with: .negative))
            #expect(!red.collides(with: .warning))
            #expect(orange.stepsAside(beside: [.negative, .warning]))
            #expect(!orange.stepsAside(beside: [.negative]))
            #expect(!red.stepsAside(beside: []))
        }
    }

    @Test("every accent collides with exactly the meanings it is measurably close to", arguments: everyAccent)
    func collisionsAreMeasured(swatch: Swatch) {
        let expected: [String: Set<String>] = [
            "red": ["negative"],
            "orange": ["warning"],
            "green": ["positive"],
        ]
        for isDark in [false, true] {
            let accent = swatch.ink(dark: isDark)
            let collisions = Set(PaletteMeaning.allCases.filter(accent.collides(with:)).map { "\($0)" })
            #expect(
                collisions == expected[swatch.name, default: []],
                "\(swatch.name), \(isDark ? "dark" : "light"): \(collisions.sorted())"
            )
        }
    }
}
