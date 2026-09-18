import Foundation
import Testing
@testable import Core

@Suite("Palette contrast")
struct PaletteContrastTests {
    private static let grounds: [(name: String, ink: PaletteInk.Pair)] = [
        ("surface", PaletteInk.surface),
        ("surfaceRaised", PaletteInk.surfaceRaised),
        ("surfaceSunken", PaletteInk.surfaceSunken),
    ]

    private static let appearances: [(name: String, isDark: Bool)] = [
        ("light", false), ("dark", true),
    ]

    @Test("the ratio is WCAG's, at the two ends everybody knows")
    func theFormulaIsTheStandardOne() {
        #expect(Contrast.relativeLuminance(of: 0x000000) == 0)
        #expect(abs(Contrast.relativeLuminance(of: 0xFFFFFF) - 1) < 0.0001)
        #expect(abs(Contrast.ratio(0x000000, 0xFFFFFF) - 21) < 0.01)
        #expect(abs(Contrast.ratio(0x777777, 0xFFFFFF) - 4.48) < 0.01)
        #expect(Contrast.ratio(0x8A9AA2, 0xFFFFFF) == Contrast.ratio(0xFFFFFF, 0x8A9AA2))
        #expect(Contrast.ratio(0x123456, 0x123456) == 1)
    }

    @Test("a colour drawn at reduced opacity is measured as what it becomes")
    func compositingIsTheThingMeasured() {
        #expect(Contrast.composited(0xFFFFFF, over: 0x000000, at: 1) == 0xFFFFFF)
        #expect(Contrast.composited(0xFFFFFF, over: 0x000000, at: 0) == 0x000000)
        #expect(Contrast.composited(0xFFFFFF, over: 0x000000, at: 0.5) == 0x808080)
        let onAccent = Contrast.composited(0xFFFFFF, over: PaletteInk.multicolorAccent.light, at: 0.75)
        #expect(Contrast.ratio(onAccent, PaletteInk.multicolorAccent.light) < Contrast.textFloor)
    }

    @Test("meaning marks clear the non-text floor on every ground they are drawn on")
    func meaningMarksClearTheNonTextFloor() {
        let inks: [(String, PaletteInk.Pair)] = [
            ("negative", PaletteInk.negative),
            ("running", PaletteInk.running),
            ("merged", PaletteInk.merged),
            ("workspaceMessage", PaletteInk.workspaceMessage),
        ]

        for (inkName, ink) in inks {
            for (appearance, isDark) in Self.appearances {
                for (groundName, ground) in Self.grounds {
                    let ratio = Contrast.ratio(ink.member(dark: isDark), ground.member(dark: isDark))
                    #expect(
                        ratio >= Contrast.nonTextFloor,
                        "\(inkName) on \(groundName), \(appearance): \(ratio.rounded(to: 2)) to 1"
                    )
                }
            }
        }
    }

    @Test("the system warning colour is measurably dim in light, and this is that measurement")
    func theWarningMarkIsDimInLight() {
        let ratio = Contrast.ratio(PaletteInk.warning.light, PaletteInk.surface.light)
        #expect(
            ratio < Contrast.nonTextFloor,
            "warning on surface, light: \(ratio.rounded(to: 2)) to 1, expected under the non-text floor"
        )
        let darkRatio = Contrast.ratio(PaletteInk.warning.dark, PaletteInk.surface.dark)
        #expect(
            darkRatio >= Contrast.nonTextFloor,
            "warning on surface, dark: \(darkRatio.rounded(to: 2)) to 1"
        )
    }

    @Test("the system tertiary label colour does not clear the text floor here, and this says so")
    func theTertiaryLabelIsBelowFloor() {
        for (appearance, isDark) in Self.appearances {
            for (groundName, ground) in Self.grounds {
                let ratio = Contrast.ratio(
                    PaletteInk.textTertiary.member(dark: isDark), ground.member(dark: isDark)
                )
                #expect(
                    ratio < Contrast.textFloor,
                    "textTertiary on \(groundName), \(appearance): \(ratio.rounded(to: 2)) to 1, confirmed below the text floor rather than assumed"
                )
            }
        }
    }

    @Test("every syntax colour clears the text floor on the surface code is drawn on")
    func syntaxClearsItsFloor() {
        let ramp: [(String, PaletteInk.Pair)] = [
            ("synKeyword", PaletteInk.synKeyword),
            ("synType", PaletteInk.synType),
            ("synString", PaletteInk.synString),
            ("synNumber", PaletteInk.synNumber),
            ("synComment", PaletteInk.synComment),
            ("synFunction", PaletteInk.synFunction),
            ("synVariable", PaletteInk.synVariable),
            ("synAttribute", PaletteInk.synAttribute),
            ("synOperator", PaletteInk.synOperator),
        ]

        for (name, ink) in ramp {
            for (appearance, isDark) in Self.appearances {
                let ratio = Contrast.ratio(
                    ink.member(dark: isDark), PaletteInk.surface.member(dark: isDark)
                )
                #expect(
                    ratio >= Contrast.textFloor,
                    "\(name), \(appearance): \(ratio.rounded(to: 2)) to 1"
                )
            }
        }
    }

    @Test("white on a fill clears the text floor")
    func fillsCarryTheirLabel() {
        for (name, ink) in [("mergedFill", PaletteInk.mergedFill)] {
            for (appearance, isDark) in Self.appearances {
                let ratio = Contrast.ratio(0xFFFFFF, ink.member(dark: isDark))
                #expect(
                    ratio >= Contrast.textFloor,
                    "white on \(name), \(appearance): \(ratio.rounded(to: 2)) to 1"
                )
            }
        }
    }

    @Test("selected text is still readable on the ground the accent derives")
    func selectedTextClearsItsFloor() {
        for (appearance, isDark) in Self.appearances {
            let ratio = Contrast.ratio(
                PaletteInk.selectedTextInk.member(dark: isDark),
                PaletteInk.accentTextSelection.member(dark: isDark)
            )
            #expect(
                ratio >= Contrast.textFloor,
                "selected text on the accent's selection fill, \(appearance): \(ratio.rounded(to: 2)) to 1"
            )
        }
    }

    @Test("a selection can be seen against the page it is on")
    func aSelectionIsFindable() {
        for (appearance, isDark) in Self.appearances {
            for (groundName, ground) in Self.grounds {
                let ratio = Contrast.ratio(
                    PaletteInk.accentTextSelection.member(dark: isDark), ground.member(dark: isDark)
                )
                #expect(
                    ratio >= 1.2,
                    "the selection fill on \(groundName), \(appearance): \(ratio.rounded(to: 2)) to 1"
                )
            }
        }
    }

    @Test("a chosen cell's fill is findable on its track")
    func thePanelTabsHoldTheirOwnFloors() {
        for (appearance, isDark) in Self.appearances {
            let fill = PaletteInk.selected.member(dark: isDark)
            let track = PaletteInk.surfaceSunken.member(dark: isDark)
            let onTrack = Contrast.ratio(fill, track)
            #expect(
                onTrack >= 1.2,
                "the chosen cell on its track, \(appearance): \(onTrack.rounded(to: 2)) to 1"
            )
        }
    }

    @Test("running is a hue of its own, and far enough from the four it is read beside")
    func runningIsNotAnyoneElse() {
        for (appearance, isDark) in Self.appearances {
            let running = PaletteInk.running.member(dark: isDark)
            let positive = PaletteInk.positive.member(dark: isDark)
            let warning = PaletteInk.warning.member(dark: isDark)
            let negative = PaletteInk.negative.member(dark: isDark)

            #expect(running != positive, "running is \(appearance)'s positive again")

            let confusable = Contrast.deltaE(running, positive)
            let bar = Contrast.deltaE(warning, negative)
            #expect(
                confusable >= bar,
                "running against positive, \(appearance): \(confusable.rounded(to: 1)) against \(bar.rounded(to: 1))"
            )

            let others: [(String, UInt32)] = [
                ("warning", warning),
                ("negative", negative),
                ("merged", PaletteInk.merged.member(dark: isDark)),
            ]
            for (name, other) in others {
                let measured = Contrast.deltaE(running, other)
                #expect(
                    measured >= bar / 2,
                    "running against \(name), \(appearance): \(measured.rounded(to: 1)) against \(bar.rounded(to: 1) / 2)"
                )
            }
        }
    }

    @Test("the busy mark cannot be mistaken for a dim one")
    func runningIsNotTheQuietInk() {
        let distinctFloor = 20.0
        for (appearance, isDark) in Self.appearances {
            let running = PaletteInk.running.member(dark: isDark)
            let quiet = PaletteInk.textTertiary.member(dark: isDark)
            let measured = Contrast.deltaE(running, quiet)
            #expect(
                measured >= distinctFloor,
                "running against textTertiary, \(appearance): \(measured.rounded(to: 1)) against \(distinctFloor)"
            )
        }
    }

    @Test("a border separates the panes it divides")
    func bordersAreFindable() {
        for (appearance, isDark) in Self.appearances {
            for (groundName, ground) in Self.grounds {
                let ratio = Contrast.ratio(
                    PaletteInk.border.member(dark: isDark), ground.member(dark: isDark)
                )
                #expect(
                    ratio >= 1.2,
                    "border on \(groundName), \(appearance): \(ratio.rounded(to: 2)) to 1"
                )
            }
        }
    }
}

private extension Double {
    func rounded(to places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}

@Suite("A state says itself in more than a colour")
struct SeverityVocabularyTests {
    @Test("calm is the only quota step with nothing to say")
    func calmIsSilent() {
        #expect(QuotaSeverity.calm.word == nil)
        #expect(QuotaSeverity.calm.symbol == nil)
        for severity in [QuotaSeverity.warning, .critical, .spent] {
            #expect(severity.word != nil, "\(severity) has no word")
            #expect(severity.symbol != nil, "\(severity) has no shape")
        }
    }

    @Test("no two quota steps share a word or a shape")
    func stepsAreToldApart() {
        let words = QuotaSeverity.allCases.compactMap(\.word)
        let symbols = QuotaSeverity.allCases.compactMap(\.symbol)
        #expect(Set(words).count == words.count)
        #expect(Set(symbols).count == symbols.count)
    }

    @Test("no two subagent outcomes share a word")
    func outcomesAreToldApart() {
        let marks: [SubagentRow.Mark] = [.working, .done, .failed, .stopped]
        let words = marks.map(\.word)
        #expect(Set(words).count == words.count)
        #expect(!words.contains(""))
    }

    @Test("a quota row says its severity out loud")
    func aRowSaysItsSeverity() {
        let line = QuotaLine(
            provider: .claudeCode,
            windowKey: "five-hour",
            title: "Claude Code, 5 hours",
            figure: "84%",
            fill: 0.84,
            severity: .warning,
            footnote: "Lifts in 40m"
        )
        #expect(line.spoken.contains("Claude Code, 5 hours"))
        #expect(line.spoken.contains("84%"))
        #expect(line.spoken.contains("Running low"))
        #expect(line.spoken.contains("Lifts in 40m"))
    }

    @Test("a calm row does not invent a verdict")
    func aCalmRowIsQuiet() {
        let line = QuotaLine(
            provider: .codex,
            windowKey: "weekly",
            title: "Codex, weekly",
            figure: "12%",
            fill: 0.12,
            severity: .calm,
            footnote: ""
        )
        #expect(line.spoken == "Codex, weekly, 12%")
    }

    @Test("an empty board still says something over the panel")
    func anEmptyBoardSpeaks() {
        let summary = QuotaBoard(providers: []).spokenSummary()
        #expect(summary.contains("Agent limits"))
        #expect(summary.contains("Nothing has reported"))
    }
}
