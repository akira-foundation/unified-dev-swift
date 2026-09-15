import SwiftUI
import AppKit
import Core

/// Unified Dev's colours.
///
/// Tahoe's own tokens, not a bespoke ramp. The one colour this app still keeps of its own is the
/// brand accent, `accent`/`accentFill`: every surface, text level, border, selection and state
/// colour below resolves to the system semantic that means the same thing (`windowBackgroundColor`,
/// `separatorColor`, the four label levels, the system selection colours, `systemRed`/`Orange`/
/// `Green`/`Blue`/`Purple` for meaning), which is what already answers Increase Contrast, Reduce
/// Transparency and Dark Mode without this file doing anything about it.
///
/// The surfaces collapse to one value under those tokens, `windowBackgroundColor` and
/// `controlBackgroundColor` being the same paint in both appearances, and that collapse is kept
/// rather than worked around: it is what "the system's tokens are the Tahoe look" means in
/// practice, and `Metrics.hairline` carries whatever separation a pane still needs.
///
/// Syntax colours (`syn*`) and the diff tints are reading semantics, not chrome, and stay as their
/// own tuned pairs: see `PaletteInk`.
enum Palette {
    // MARK: Surfaces
    //
    // Four values and one rule. Measured light: FFFFFF / F7FAFA / F1F5F6 / FFFFFF, rule D6E0E4.
    // Measured dark: 0A1A25 / 0C1E2A / 0E202D / 16303F, rule 1E3F53.

    /// The ground the centre column stands on: the transcript, Home, Search, Settings.
    ///
    /// Identical to `surface` on purpose. They are two names for the reading ground because the
    /// call sites mean different things by them, not because the colour differs; if they ever
    /// diverge the window has grown a surface it does not need.
    static let windowBackground = Color(nsColor: .windowBackgroundColor)

    /// The chrome colour for a strip of small controls that is not the sidebar column itself: the
    /// tab strip, Home's status bar, the About window's footer.
    ///
    /// The sidebar column no longer takes this value. `SidebarView` sits on the system's own
    /// sidebar material now, through `NavigationSplitView`, rather than on a named colour.
    static let controlStrip = Color(nsColor: .windowBackgroundColor)

    /// Content areas: the transcript, the inspector, anything holding text.
    static let surface = Color(nsColor: .windowBackgroundColor)

    /// A raised control: a segmented control's selected cell, a bordered button, a browser chip.
    static let surfaceRaised = Color(nsColor: .controlBackgroundColor)

    /// A recessed strip: gutters, hunk headers, tool detail blocks, the composer box, the panel.
    ///
    /// `controlBackgroundColor`, the same as `surfaceRaised`: on Tahoe the two are one value, and
    /// the separation a "recessed" strip used to carry on its own now comes from `Metrics.hairline`
    /// alone, which is the system's own answer rather than a second grey invented to fake one.
    static let surfaceSunken = Color(nsColor: .controlBackgroundColor)

    // MARK: Overlays
    //
    // `hover` is a tint painted over whatever is underneath, so it is an alpha on white or black
    // rather than a colour of its own. The two selection fills below are not: they are opaque
    // steps of Unified Dev's ramp, for the reasons written on each. Never write any of the three as
    // 0xRRGGBBAA, which was the original bug behind the solid black selection bar: 0x00000014 is
    // the number 20, indistinguishable from an opaque dark blue, so the alpha was never applied.

    /// Measured off the mockup: four percent ink in light, five and a half in dark. It was six in
    /// both, and six percent black on white is a visibly grey slab under the pointer where the
    /// same figure in dark is barely a lift.
    static let hover = Color(nsColor: hoverNSColor)

    /// The same wash as an `NSColor`, for the transcript's text views. One definition, read two
    /// ways, so a span of inline code sits on the same ground whichever renderer drew it.
    static let hoverNSColor = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 1, alpha: 0.055)
            : NSColor(white: 0, alpha: 0.04)
    }

    /// The scrim the search panel puts over the window behind it.
    ///
    /// An appearance provider rather than two call sites, so it follows a switch between light and
    /// dark without the panel being told about it, which is the same arrangement `hoverNSColor`
    /// above and the title bar's paint both keep. It is black in both, and the two opacities are
    /// `SearchPanelLayout`'s, where the measurement that forced two of them is written down.
    static let panelScrim = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return NSColor(white: 0, alpha: SearchPanelLayout.dim(isDark: isDark))
    })

    /// A selected row in a list that is not the key window's focus.
    static let selected = Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
    /// Selection in a focused list inside the key window, where macOS uses the accent colour.
    /// Selection and control emphasis supplied by macOS.
    ///
    /// Interactive colour follows the user's system accent. Brand colour remains available through
    /// `accent` and `accentFill` for identity and status marks that are not controls.
    static let controlAccent = Color(nsColor: .controlAccentColor)
    static let selectedEmphasized = controlAccent
    /// The ink that survives an emphasized fill. `alternateSelectedControlTextColor` is AppKit's
    /// name for it, and it is the one semantic colour in this file that is right without argument.
    static let selectedEmphasizedText = Color(nsColor: .alternateSelectedControlTextColor)

    // MARK: Lines

    /// The rule between two panes, and under every strip. `Metrics.hairline` draws it at a full
    /// point, which is what AppKit's own split view divider has always been.
    static let border = Color(nsColor: .separatorColor)

    /// What `NSSplitView` draws its own divider in, measured rather than guessed: black at ten
    /// percent in light, and opaque black on the dark ramp. `separatorColor` is a different
    /// colour entirely there, white at ten percent, which is why a rule of ours never matched the
    /// divider beside it. The split view's own colour cannot be changed without a subclass the
    /// controller refuses to take, so the rules that have to meet it take this instead.
    ///
    /// Only the ones that meet it. Every other boundary in the window stays `border`: a pass that
    /// put this colour on all of them turned every rule in the transcript black.
    static let paneDivider = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.name == .darkAqua || appearance.name == .vibrantDark
            ? NSColor.black
            : NSColor.black.withAlphaComponent(0.10)
    })

    // MARK: Text

    static let textPrimary = Color(nsColor: .labelColor)
    static let textSecondary = Color(nsColor: .secondaryLabelColor)
    /// The system's own third rung. It measures under the text floor on this app's grounds: see
    /// `PaletteContrastTests.textClearsItsFloor`, which reports the ratio rather than hiding it
    /// behind a hand-tuned substitute.
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)

    /// The tertiary rung over a glass material. `tertiaryLabelColor` is itself resolved against the
    /// effective appearance AppKit draws it in, glass included, so there is no longer a separate
    /// value to hold here; this is `textTertiary` under another name for the call sites that used
    /// to need the split.
    static let textTertiaryOnGlass = textTertiary

    /// Ink on anything Unified Dev has filled with a colour of its own.
    ///
    /// Spelled as the selection's ink rather than built from the same `NSColor` a second time,
    /// which is what it was. Two names for one value is the arrangement `link` and `accent`
    /// already have and document; two independent constructions of one value is how the pair
    /// drifts the first time one of them is retuned.
    static let textInverted = selectedEmphasizedText

    /// What a field says before anything is typed into it. Half ink, where the tertiary label is
    /// a quarter, which is why a placeholder written as `textTertiary` reads as disabled.
    static let textPlaceholder = Color(nsColor: .placeholderTextColor)

    /// A control that is there and cannot be pressed.
    ///
    /// Semantic, and it is the exception `textTertiary` above argues for rather than a fourth rung
    /// of Unified Dev's own. That note says the system's third rung is what the system means for a
    /// disabled control and that Unified Dev's tertiary is deliberately not it, which leaves nothing in
    /// this file for a control that really is disabled. Written as `textTertiary`, the browser
    /// toolbar's Back arrow was a shade off the Forward arrow beside it and read as pressable at
    /// every size the pane is drawn at, which is measured off `BrowserToolbarGallery` rather than
    /// argued: the first row of that page has both arrows dead and looked exactly like the second,
    /// which has neither.
    ///
    /// `disabledControlTextColor` rather than `tertiaryLabelColor`, though they are close, because
    /// this is a control and not a label, and it is the one AppKit moves when the user turns on
    /// Increase Contrast.
    static let textDisabled = Color(nsColor: .disabledControlTextColor)

    // MARK: Text editing
    //
    // The three colours AppKit uses inside a text view. Each of them tracks something the accent
    // colour alone does not: the focus ring follows the Full Keyboard Access setting, the caret
    // follows the text colour on high contrast, and the selection is the paler fill a text run
    // gets rather than the solid one a list row gets.
    //
    // All three remain semantic and derive from `controlAccentColor`, the same source exposed as
    // `Palette.controlAccent`. Unified Dev's AccentColor asset supplies the default under Multicolour,
    // while an explicit user-selected accent wins. Native and custom interactive surfaces
    // therefore stay aligned.

    /// The focus ring around the control that has keyboard focus.
    static let focusRing = Color(nsColor: .keyboardFocusIndicatorColor)
    /// The caret.
    static let caret = Color(nsColor: .textInsertionPointColor)
    /// Selected text inside an editable or selectable text view.
    static let textSelection = Color(nsColor: .selectedTextBackgroundColor)

    // MARK: Meaning

    /// Unified Dev's brand accent for identity, links and status ink.
    ///
    /// It deliberately does not paint controls or selections. Those use `controlAccent`, which
    /// follows the user's system preference. See `PALETTE.md` in the brand folder.
    ///
    /// A pair, not a colour, because the ramp is explicit that its bottom half is for dark grounds
    /// and its top half for light. Unified Dev `#4FD8C4` measures 10.6 to 1 on the dark surface and 1.7
    /// to 1 on the light one, so it can never be text on light; the ramp's answer for that is Unified Dev
    /// Ink `#0C7A6E`, which measures 5.1. Both are the same hue, so a glyph that is teal in dark is
    /// recognisably the same glyph in light.
    ///
    /// This is for ink and strokes that convey Unified Dev identity or status, not interactive emphasis.
    static let accent = dynamic(PaletteInk.accent)

    /// The same pair as an `NSColor`, for the layers that hold a `CGColor` and therefore have to be
    /// handed a colour already resolved against the window's appearance.
    static let accentNSColor = dynamicNSColor(light: PaletteInk.accent.light, dark: PaletteInk.accent.dark)

    /// A brand fill capable of carrying light text, for identity surfaces such as the user's
    /// message bubble. Controls and selections use `controlAccent` instead.
    ///
    /// The accent colour, the ramp's anchor and the only colour in it that works on both grounds. White
    /// on it measures 5.2 to 1. Unified Dev itself cannot do this job: white on
    /// `#4FD8C4` is 1.6 to 1, an unreadable row.
    ///
    /// This also supplies the app's default AccentColor when the system preference is Multicolour.
    /// An explicit user-selected accent still wins for native and custom interactive controls.
    static let accentFill = dynamic(PaletteInk.accentFill)

    /// An address in running text: underlined, and this colour.
    ///
    /// The accent, deliberately and not a blue of its own. A link is the app pointing at
    /// somewhere else, which is the same thing every tinted glyph in the window is doing, and a
    /// system blue here would be the one colour in Unified Dev that came from somewhere else. It is
    /// named rather than spelled `accent` at the call site so that the day a link needs to stop
    /// looking like a chip's tick, there is one line to change. Measured 5.2 to 1 on the light
    /// page and 10.1 to 1 on the dark one, both AA for body text.
    ///
    /// The underline is not decoration and is not optional: it is what makes the link findable
    /// without colour vision, and `linkInverted` below leans on it almost entirely.
    static let link = accent

    /// The same ink as an `NSFont`-side colour, for the transcript's text views. Built from the
    /// same pair rather than converted from `link`, so the two can never drift apart and the
    /// dynamic pair survives: an `NSTextView` resolves it against the window it is in.
    static let linkNSColor = accentNSColor

    /// Healthy, done, passed. `systemGreen`, not the brand accent.
    ///
    /// It used to be `accent` itself, on the argument that the ramp has one hue and does not need
    /// a second green. Under Tahoe's own tokens that argument is the wrong way round: the accent is
    /// the one colour this app keeps of its own, and tying it to a status meaning is what stopped
    /// a passing check and a plain link from ever being told apart. `positive` and `accent` are
    /// independent now, and nothing stops them landing on the same hue by coincidence again, which
    /// is what `PaletteContrastTests` is for.
    static let positive = dynamic(PaletteInk.positive)

    /// The wash and the rule of the agent's question card while it is holding the turn open.
    ///
    /// A named pair rather than an opacity at each call site, because the card paints the same
    /// tint twice, as its fill and as its border, and two literals in one view is how the two
    /// drift apart. The wash is deliberately faint: the card sits in the transcript for as long
    /// as the person thinks, so it has to mark itself out without shouting over the prose it
    /// interrupted.
    static let questionWash = accent.opacity(0.06)
    static let questionBorder = accent.opacity(0.4)
    /// The same card once the question is settled: barely off the page, behind the plain border,
    /// so a finished question reads as part of the record rather than as something still waiting.
    static let questionWashSettled = accent.opacity(0.03)

    /// The amber twin of the set above: the wash and the rule of a card that wants something of
    /// the reader without being an error. The permission ask while it is holding the turn open,
    /// and a retry while it is counting down.
    ///
    /// Named for the same reason `questionWash` is, and named because the two cards had already
    /// drifted apart: the ask card was `0.07` over `0.46` and the retry `0.07` over `0.28`, two
    /// amber plates a reader meets in one scroll with visibly different rules. The border takes
    /// `questionBorder`'s rung rather than either of the two literals it replaces, since neither
    /// of them had an argument behind it and the question card is the same card in another colour.
    static let cautionWash = warning.opacity(0.07)
    static let cautionBorder = warning.opacity(0.4)
    /// The ask card once it has been answered, matching `questionWashSettled`.
    static let cautionWashSettled = warning.opacity(0.03)

    /// Something went wrong: a failed check, an error row, a deletion count. `systemRed`.
    static let negative = dynamic(PaletteInk.negative)

    /// The stop control, which is a quieter red than a failure is.
    ///
    /// `negative` is right for something that went wrong. The stop button is not a failure: it sits
    /// in the composer for the whole length of a turn, and at full saturation it reads as an alarm
    /// about work that is going perfectly well. `systemRed` at 85 percent over the window
    /// background keeps the meaning and drops the volume; see `PaletteInk.stop` for why 85.
    static let stop = Color(nsColor: .systemRed).opacity(0.85)

    /// Something needs attention but nothing is broken: setup that failed and can be run again,
    /// checks still going, a rate limit. `systemOrange`.
    static let warning = dynamic(PaletteInk.warning)
    /// An agent mid turn: the sidebar's dot, the tab's dot, and the rule under the tab strip.
    /// `systemBlue`, and it must never equal `positive`: `PaletteContrastTests` pins that a running
    /// mark and a passing one stay two hues apart, which is the report this colour exists to answer.
    static let running = dynamic(PaletteInk.running)

    /// The same pair as an `NSColor`, for `ActivityRuleView`'s layers. See `accentNSColor`.
    static let runningNSColor = dynamicNSColor(
        light: PaletteInk.running.light, dark: PaletteInk.running.dark
    )

    /// A pull request that has landed. `systemPurple`: the one meaning in the app that is neither
    /// good news nor bad, and not the brand accent, which stays reserved for identity.
    static let merged = dynamic(PaletteInk.merged)

    /// A merge as a fill with light text on it: the Archive button on a landed pull request.
    /// `systemPurple`, darkened until white clears the text floor on it in both appearances; see
    /// `PaletteInk.mergedFill`.
    static let mergedFill = dynamic(PaletteInk.mergedFill)

    // MARK: Diffs
    //
    // Stated as an alpha over whatever the line is drawn on, rather than as an opaque hex per
    // appearance. That is the difference between a wash and a slab: a wash follows the surface,
    // so moving the dark ground from charcoal to deep blue leaves these correct, where the eight
    // opaque values they replaced each had to be retuned by hand or they drifted off the ground
    // and read as coloured tape stuck over the code.
    //
    // Thirteen and fourteen percent, because a deletion has to look as strong as an addition and
    // red carries further than green at the same alpha. The emphasis pair is roughly double, for
    // the run of characters inside a changed line.

    /// Added lines, and only added lines. `positive`, the window's other green, is a wash the one
    /// place it cannot be used: at the ground's own alpha a systemGreen wash reads correctly here,
    /// but this line kept its own tuned pair rather than take `positive`'s, since a diff tint is
    /// read against the code it colours and not against the rest of the window's state colours.
    ///
    /// Teal against red does separate better than green against red under deuteranopia, which is
    /// a real argument and was weighed. It loses to two things: green for an added line is close
    /// to universal across git tooling, and this is the diff the owner looked at and approved.
    static let diffPositive = dynamic(PaletteInk.diffPositive)

    static let diffAddBackground = diffPositive.opacity(0.13)
    static let diffAddEmphasis = diffPositive.opacity(0.28)
    static let diffDeleteBackground = negative.opacity(0.14)
    static let diffDeleteEmphasis = negative.opacity(0.30)

    /// A line under review, and the band holding its comment. The one amber wash in the window,
    /// on `warning`'s hue, because the diff's own washes have already spent green and red: a
    /// comment is neither an addition nor a problem, and either of those colours would claim it
    /// is. Two steps of the same wash rather than two hues, so a commented line and its band read
    /// as one annotation instead of a line with a strip stuck under it. Both are translucent for
    /// the reason the diff washes are: the ground shows through, so neither needs a dark twin.
    static let reviewLine = warning.opacity(0.14)
    static let reviewBand = warning.opacity(0.07)

    // MARK: Syntax

    static let synKeyword = dynamic(PaletteInk.synKeyword)
    static let synType = dynamic(PaletteInk.synType)
    static let synString = dynamic(PaletteInk.synString)
    static let synNumber = dynamic(PaletteInk.synNumber)
    static let synComment = dynamic(PaletteInk.synComment)
    static let synFunction = dynamic(PaletteInk.synFunction)
    static let synVariable = dynamic(PaletteInk.synVariable)
    static let synAttribute = dynamic(PaletteInk.synAttribute)
    static let synOperator = dynamic(PaletteInk.synOperator)
    /// A constant is a number as far as this ramp is concerned, and saying so is cheaper than
    /// keeping two copies of one pair in step.
    static let synConstant = synNumber

    /// A colour that differs between appearances, for the few cases where no semantic colour
    /// means the right thing. Both arguments are plain 0xRRGGBB.
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: dynamicNSColor(light: light, dark: dark))
    }

    /// The same, from the core's table. Every named colour in this file goes through here, so the
    /// numbers are somewhere `Tests/CoreTests` can walk them: see `PaletteInk`.
    static func dynamic(_ ink: PaletteInk.Pair) -> Color {
        dynamic(light: ink.light, dark: ink.dark)
    }

    /// The same thing as an `NSColor`, for the handful of places that talk to AppKit directly.
    static func dynamicNSColor(light: UInt32, dark: UInt32) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(rgb: isDark ? dark : light)
        }
    }
}

extension NSColor {
    /// Plain 0xRRGGBB. There is deliberately no packed-alpha form: alpha belongs in
    /// `Color.opacity`, where it cannot be mistaken for part of the colour.
    convenience init(rgb: UInt32) {
        self.init(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    /// Repo accent colours are stored as plain hex strings in SQLite.
    ///
    /// Read by `HexColor`, in the core and unit tested, rather than by a second rule here: this
    /// used to hand the string to `UInt32(_:radix:)`, which reads `abc` as the number `0x000ABC`
    /// and paints a project near black where every other tool reads `#AABBCC`.
    init(hexString: String) {
        guard let parsed = HexColor(hex: hexString) else {
            self.init(nsColor: NSColor(rgb: 0x4C8DF6))
            return
        }
        self.init(nsColor: NSColor(
            srgbRed: CGFloat(parsed.red) / 255,
            green: CGFloat(parsed.green) / 255,
            blue: CGFloat(parsed.blue) / 255,
            alpha: 1
        ))
    }

    /// The way back, for a colour the user picked in a colour well.
    ///
    /// Lives here rather than in whichever feature view happens to need it, because the two
    /// directions have to agree about the colour space and about upper case, and they can only be
    /// held to that if they can be read together. Two feature views had a copy each.
    var hexString: String? {
        guard let color = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        return [color.redComponent, color.greenComponent, color.blueComponent]
            .map { component in
                let byte = String(Int((component * 255).rounded()), radix: 16, uppercase: true)
                return byte.count == 1 ? "0" + byte : byte
            }
            .joined()
    }
}

/// Type scale, built on the system text styles so it follows the user's text size rather than
/// pinning everything to a point size we happened to like.
///
/// The rungs are `ScaledFont` rather than `Font` so that a subtree can be set larger without every
/// call site being rewritten; see that type for why macOS forces the question. Outside a
/// conversation the scale is one and each rung resolves to the same `Font` it always was.
///
/// Five rungs, and every name lands on one of them: 15 / 13 / 12 / 11 / 10, where 15 only ever
/// appears inside prose. There used to be three, because on macOS `.caption`, `.caption2` and
/// `.footnote` all resolve to 10 points: `caption` and `micro` were one size wearing two names,
/// `codeSmall` and `codeTiny` likewise, `title` was a hand-rolled `.headline`, and 11, the one
/// step the app actually wanted, was never used at all. `.subheadline` is that step, and it is
/// where everything that sat at 10 for want of anywhere else has moved to.
enum Typo {
    /// Large brand copy, the system face: no bundled display font any more, per the instruction
    /// that the system's own type IS the Tahoe look.
    static let display = ScaledFont(.largeTitle, weight: .light)
    /// A page heading inside the welcome sequence.
    static let displayHeading = ScaledFont(.title2, weight: .medium)
    static let displayTracking: CGFloat = -0.6
    /// 15. The only rung above reading size, for the two places something has to read as a heading
    /// rather than as a bold sentence: a heading inside agent prose, and the state of the pull
    /// request at the top of the inspector.
    ///
    /// The second one is here rather than local to the inspector because it is the same judgement,
    /// not a second one. A heading set at body size with a weight on it is a bold sentence, and
    /// the inspector's state line was a rung BELOW the file names it heads, which is worse again.
    /// Anything that has to sit above reading size belongs on this rung; a sixth rung invented for
    /// one strip is how a five rung scale stops being one.
    static let heading = ScaledFont(.title3, weight: .bold)
    /// 13 bold. `.headline` is the system's own heading style at reading size, so saying so lets
    /// macOS treat it as a heading rather than as body with a weight bolted on.
    static let title = ScaledFont(.headline)
    /// 13. Reading size: prose, and anything the user is meant to read rather than scan.
    static let body = ScaledFont(.body)
    static let bodyEmphasis = ScaledFont(.body, weight: .medium)
    /// 12. The workhorse: row labels, controls, anything scanned rather than read.
    static let label = ScaledFont(.callout)
    static let labelEmphasis = ScaledFont(.callout, weight: .medium)
    /// 11. Supporting text that still has to be legible: a hint under a field, a link out of a
    /// block, the name on a chip.
    static let caption = ScaledFont(.subheadline)
    static let captionEmphasis = ScaledFont(.subheadline, weight: .medium)
    /// 10, the floor, and the reason it is medium rather than regular. Only for something that is
    /// read off the thing beside it: a count, a duration, a unit.
    static let micro = ScaledFont(.footnote, weight: .medium)

    /// The letterspacing an uppercased `micro` label is set with: the question card's header
    /// chip. Capitals at ten points set nearly solid, and the scale carries no uppercase rung of
    /// its own, so the air has to be given by hand. Named so the next uppercased label cannot
    /// pick a second value.
    static let microTracking: CGFloat = 0.6

    /// The same rungs in monospace, for anything whose columns have to line up: code, a path, a
    /// diff stat. They step with their proportional twins so a filename set beside a label does
    /// not read as a size apart from it.
    static let code = ScaledFont(.callout, design: .monospaced)
    static let codeSmall = ScaledFont(.subheadline, design: .monospaced)
    static let codeTiny = ScaledFont(.footnote, design: .monospaced)
}

enum Metrics {
    static let sidebarWidth: CGFloat = 260
    static let inspectorWidth: CGFloat = 380

    /// What the centre column may never be squeezed below.
    ///
    /// It was `DetailSplitViewController.detailMinimum`, and that controller is gone: the
    /// inspector is a column of the window now rather than a pane of a split view of ours. The
    /// number is unchanged and `WindowWidths` still adds it up the same way.
    static let centreColumnMinimum: CGFloat = 420

    /// What the centre column opens at, which is the rest of a window at its own minimum.
    static let centreColumnIdeal: CGFloat = 520

    /// What the inspector may never be squeezed below. Was `inspectorMinimum` on the same
    /// controller.
    static let inspectorMinimum: CGFloat = 280

    /// And what it may be dragged out to, which was that controller's `inspectorMaximum`.
    static let inspectorMaximum: CGFloat = 760
    /// Matches the row height AppKit uses for a source list.
    static let rowHeight: CGFloat = 28
    /// Corner radii. Radii only: a gap between two views comes from the spacing scale below, even
    /// where the number happens to match.
    ///
    /// The scale is the product's own, taken from `--radius: 1rem` in the web app's tokens and
    /// stepped down from there, and it is deliberately rounder than what this code inherited.
    /// Six points was a pre-Tahoe number: on a panel or a card it reads as a square corner, which
    /// is exactly what the owner reported seeing.
    static let cornerLarge: CGFloat = 16
    static let corner: CGFloat = 12
    static let cornerSmall: CGFloat = 8

    static let gutter: CGFloat = 12

    // A small button at the trailing edge of a header (the project's `+`, the button that adds a
    // project, the project settings window's own header control) used to be hand-sized to this
    // box. It is a `.buttonStyle(.glass)` control now, sized by `.controlSize(.small)` rather than
    // by an explicit frame: a fixed 24 by 15 box drawn under `.glass` is a squat rectangle rather
    // than the small round control the style is meant to draw. `HoverCardPlacement`'s own comment
    // still names the number this replaced, for the click-target reasoning that carries over.
    /// One point, which on Retina is two physical pixels.
    ///
    /// It was one physical pixel, which is an iOS and web idea rather than a Mac one: AppKit's own
    /// split view divider, the rule under a table header and the line under a toolbar are all a
    /// full point. At half a point, drawn in a separator colour that is already only a 25 unit
    /// step, the rules in this window were not so much subtle as absent, and every pane floated.
    /// The name stays because a one point rule is still what everyone calls a hairline.
    static let hairline: CGFloat = 1
    /// A device-pixel-style outline for controls and cards. Structural pane dividers remain a full
    /// point through `hairline`.
    static let outline: CGFloat = 0.5

    // MARK: Spacing
    //
    // One scale for the whole window. These used to be literals at every call site, so the
    // sidebar and the inspector drifted a point or two apart on every row they both draw, and
    // where there was no literal a corner radius was borrowed instead, which tied a gap to a
    // rounding for no reason other than the two numbers happening to match.

    /// Between two things that read as one thing, such as a glyph and its count.
    /// Two lines that are one thing: a title and the line under it, set closer than a gap.
    ///
    /// One point rather than none, because none lets the two baselines collide at large text
    /// sizes. It is a hairline of air rather than a spacing choice, which is why it has a name of
    /// its own instead of being `spacingTight` used loosely.
    static let spacingHair: CGFloat = 1

    static let spacingTight: CGFloat = 2
    /// Between a label and the number beside it.
    static let spacingSmall: CGFloat = 4
    /// Between controls in a row.
    static let spacing: CGFloat = 6
    /// Between the groups a row falls into.
    static let spacingWide: CGFloat = 8
    /// What a row keeps from the edge of its pane.
    static let inset: CGFloat = 10
    /// What a full-width pane of content keeps from the window edge. Larger than `inset`, which
    /// is a row's margin inside a narrow column.
    static let pane: CGFloat = 24

    // MARK: Marks

    /// The project's mark: `RepoIcon`, in the sidebar header, on Home, in search results and in
    /// the toolbar title. It was a 9 point dot, which is the size of a bullet and could only ever
    /// carry a colour; at source list icon size it carries the project's initials as well.
    static let repoIcon: CGFloat = 16
    /// The same mark set inline in a line of caption text, where the full size outweighs the
    /// words beside it.
    static let repoIconSmall: CGFloat = 13
    /// The box a sidebar row's state glyph sits in, so the glyphs line up down the column
    /// whichever state each row is in. It is the point size of the name beside them, not the cap
    /// height of it, which measures 9.16 at that rung.
    ///
    /// A box, and not a size. What a mark draws INSIDE it is `glyphInk`, and the gap between the
    /// two is the whole of the report the three constants under this one were written for.
    static let glyph: CGFloat = 13

    /// What a round mark in that box actually puts on the page.
    ///
    /// Measured rather than chosen, because the number a mark is given says nothing about the
    /// number it draws. An SF Symbol sits inside its em box with its own bearing, so a filled one
    /// comes out under the box it is framed in; a `Circle()` fills the frame it is handed exactly.
    /// Hand the two the same 13 and they are not the same size, which is how a column meant to
    /// read as one family ends up reading as two.
    ///
    /// The report was "that green dot feels too big", with a filled tick, a busy dot and a dotted
    /// ring in three rows of one project. Measured off a headless render of the real symbols at
    /// twenty times, in the configuration this column asks for (`Typo.caption`, semibold,
    /// `.imageScale(.medium)`): every round mark draws 11.25 across, `circle.fill`,
    /// `checkmark.circle.fill`, `xmark.circle.fill`, `slash.circle`, `clock` and `circle.dotted`
    /// alike, which is what makes this one number instead of thirteen.
    static let glyphInk: CGFloat = 11.25

    /// The bare disc in that same column: the unread mark, which is `circle.fill` a type rung
    /// down, `Typo.micro` against `Typo.caption`.
    ///
    /// Ten elevenths of the ink above, because a symbol's ink tracks its point size one for one:
    /// measured, 11.25 at the eleven point rung and 10.25 at the ten. Written as the ratio of the
    /// two rungs rather than as a measurement of its own, so a column that changes rung moves
    /// both marks together.
    static let glyphDisc: CGFloat = glyphInk * 10 / 11

    /// A status dot, sized to sit on a text baseline rather than to be noticed on its own: the
    /// busy mark in the sidebar, on a tab and in the transcript, and the bullets the inspector and
    /// the settings set beside a line.
    ///
    /// Derived, and that is what the report bought. It was a free six, chosen against a
    /// measurement of the unread disc that had been taken at the wrong image scale, so the one
    /// mark in the column drawn as a shape rather than as a symbol came out at little over half
    /// of what it stood beside.
    ///
    /// The dot swells by `BusyDot.peakScale` while it works, and the one thing it must never do
    /// is reach the unread disc: that is the same shape in another hue, and two circles of one
    /// size would be told apart only by which of them happened to be moving. So the peak is set
    /// at nine tenths of the disc and the resting figure falls out of it: 6.8 at rest and 9.2 at
    /// the top of the pulse, against the disc's 10.2 and the box's 13.
    static let dot: CGFloat = glyphDisc * 0.9 / CGFloat(BusyDot.peakScale)
    /// What a `Chip` keeps inside its fill. Named because the transcript footer draws a two colour
    /// chip by hand next to a real one, and the two have to be the same shape.
    static let chipInsetH: CGFloat = 5
    static let chipInsetV: CGFloat = 2
    /// A strip of small controls along the edge of a pane: the sidebar's status bar, the
    /// inspector's pull request strip and its tab row.
    static let barHeight: CGFloat = 32
    /// A control drawn with a fill of its own inside one of those strips: Home's search field, the
    /// browser bar's address pill and the capsule its arrows sit in. Five points of ground above
    /// and below, which is the clearance a bare glyph in the same strip already has.
    static let controlHeight: CGFloat = 22
}

/// How far off the window a floating thing is lifted.
///
/// Three call sites had invented three recipes for one question: `MenuPanel` at 0.24 over twelve
/// points, `JumpToNewestPill` at 0.18 over four and 0.28 over twelve under the pointer, and the
/// pane drag ghost at 0.18 over eight. Nothing distinguished them; they were written on three
/// days. Two levels are enough for what the window actually has, and they are named for what the
/// thing is doing rather than for how dark the shadow is.
///
/// Black rather than the label colour, in both. A shadow tinted with `labelColor` becomes a white
/// glow in dark appearance, which is the opposite of what a shadow is for, and every one of the
/// three call sites had already had to write that down for itself.
enum Elevation {
    /// A control sitting on the page: the jump pill at rest.
    case resting
    /// A panel open over the window, or something carried under the pointer.
    case lifted

    var opacity: Double {
        switch self {
        case .resting: 0.18
        case .lifted: 0.24
        }
    }

    var radius: CGFloat {
        switch self {
        case .resting: Metrics.spacingSmall
        case .lifted: Metrics.gutter
        }
    }

    var offset: CGFloat {
        switch self {
        case .resting: Metrics.spacingTight
        case .lifted: Metrics.spacingSmall
        }
    }
}

extension View {
    func elevation(_ level: Elevation) -> some View {
        shadow(color: .black.opacity(level.opacity), radius: level.radius, y: level.offset)
    }
}

/// How a pane arrives and leaves.
///
/// One curve for every pane SwiftUI draws, because two panes that move at different speeds read as
/// two apps. Short and without overshoot: a pane is furniture, and furniture that springs is a
/// toy. Call sites drop it for Reduce Motion rather than substituting a slower one, because the
/// setting is about movement, not about speed.
///
/// The inspector column is the one pane not on this curve, and it is not on it because it is not
/// SwiftUI's: it is an `NSSplitViewItem` collapsing under AppKit's own animator. `inspector` below
/// is the number that movement actually runs at, and what it exists for is that something SwiftUI
/// draws has to travel with it.
enum Motion {
    static let pane: Animation = .easeOut(duration: 0.18)

    /// The inspector column arriving and leaving, and the pull request band arriving with it.
    ///
    /// It was three parts of one movement, drawn by three different things, and it is two now: the
    /// window's search field was the third and it is a panel rather than a toolbar item. The
    /// column is an `NSSplitViewItem` under AppKit's animator. The band along the top of it is a
    /// title bar accessory, because it sits in the title bar rather than inside the pane. The
    /// field was an `NSSearchToolbarItem`, packed by `NSToolbar` into whatever width that
    /// accessory left it.
    /// That is why they used to arrive at different times: the band was drawn or it was not, with
    /// nothing in between, so it appeared whole on the frame the toolbar button was pressed while
    /// the column spent a quarter of a second sliding in underneath it (the owner's words were "bit
    /// jarring now"), and the field then popped 379 points sideways on the frame the accessory
    /// changed size.
    ///
    /// So the number lives here rather than inside any of them, and all three read it.
    /// `DetailSplitViewController` sets it on the `NSAnimationContext` the collapse runs in, and
    /// `TitleBarStripController` walks the accessory's frame across it a frame at a time, which
    /// carries the band and the field together. See `InspectorSlide` for the curve, which has to be
    /// the `easeInEaseOut` the animation context is given for the same reason this length is shared.
    ///
    /// A quarter of a second is what an `NSAnimationContext` defaults to, which is what the column
    /// has always collapsed in, so writing it down changed nothing about how the pane feels. It is
    /// deliberately not `pane`: this movement belongs to the split view and the other two are
    /// joining it, and a speed chosen here that the split view then declined to use would put them
    /// back out of step, which is the whole bug.
    ///
    /// `hoverSeconds` below is the same idea for the hover speed, and exists for the same reason:
    /// an `NSAnimationContext` takes a `TimeInterval` and cannot be handed an `Animation`, so
    /// anything AppKit plays needs the length written down separately or it writes its own.
    static let inspectorSeconds: TimeInterval = 0.25

    /// A hover state fading in, and a disclosure settling. See the sidebar rows.
    ///
    /// Shorter than `pane`, and the only speed in this file that is: a hover has to be under way
    /// before the cursor has finished arriving, or the row reads as lagging rather than as
    /// responding. Named because five call sites had grown their own literals (0.12 twice, 0.15,
    /// 0.2 once) and a file that argues one window has one speed cannot also hold four of them.
    ///
    /// A sixth had grown one since: a tab's favicon crossfading in `TabItemIcon`, spelled out as
    /// `.easeInOut(duration: 0.12)`, which is this constant with the name taken off. Naming a
    /// speed only stops the drift if the next call site reads the name.
    static let hoverSeconds: TimeInterval = 0.12
    static let hover: Animation = .easeInOut(duration: hoverSeconds)

    /// A pane's own length, borrowed by anything that settles at the same speed.
    ///
    /// It used to be the row settle, and `RowArrival` no longer reads it: what a row arriving is
    /// owed is opacity paired with a small rise, which is two numbers rather than a curve, and two
    /// numbers describing what the transcript is allowed to animate belong in `TranscriptMotion`
    /// where there is something to test them. What is left here are the three call sites that
    /// wanted the length alone.
    ///
    /// The same curve and the same length as `pane`, deliberately and not by accident: a window
    /// with one speed is the whole argument above, and a row arriving is if anything a smaller
    /// event than a pane travelling, so it has no case for being the slower of the two. It is
    /// named separately because it answers a different question and a later answer to one of them
    /// should not silently become the answer to both.
    ///
    /// Opacity only, with no movement under it. A row that slid or grew into place would be
    /// announcing itself, and what is wanted is the opposite: something that reads as the row
    /// having settled rather than as anything having been played. `easeOut` is what makes the
    /// short length carry, because it puts most of the opacity in the first third and spends the
    /// rest arriving.
    static let arrival: Animation = .easeOut(duration: 0.18)

    /// A transcript being drawn again after it has been held back: at its new width when a divider
    /// is let go, and at all when the conversation a pane was pointed at has landed in it.
    ///
    /// A duration rather than an `Animation` because what plays it is a `CATransition` on a layer.
    /// The same length as `pane`, deliberately: both are a pane's own movement finishing rather
    /// than an event of their own. Not `inspectorSeconds`, because a quarter of a second spent
    /// crossfading text that is already laid out reads as a wipe. See `TranscriptHoldView`.
    static let revealSeconds: TimeInterval = 0.18

    /// How long the pointer has to rest before a card opens under it: the composer's file chip,
    /// and the sidebar row's.
    ///
    /// Not an animation, which is why it stands slightly apart from the rest of this file, and
    /// here anyway because it is the same kind of decision: how the window responds to a pointer.
    /// It was a private constant inside `ComposerTextView` and a second one would have been the
    /// first thing `WorkspaceHoverCardPresenter` wrote, which is how two surfaces end up
    /// answering one question differently.
    ///
    /// The question is whether the pointer is RESTING on something or crossing it. A sidebar row
    /// is 32 points tall and thirty of them are stacked, so a hand sweeping the pane at a
    /// comfortable thousand points a second crosses one in about thirty milliseconds: anything
    /// above a couple of hundred already tells the two apart, and what the rest buys is that a
    /// deliberate pause somewhere in the middle of a sweep does not open a card either. Longer
    /// than this and resting on a row starts to feel like nothing is going to happen.
    static let hoverCardDelay: Duration = .milliseconds(350)
}

// MARK: - Materials

/// Content strips stay opaque. The window title bar and navigation sidebar use their existing
/// native materials, not per-view effect layers added to the scrolling surfaces here.
extension View {
    /// The strip a tab bar sits in: the chrome colour with the pane's top edge already on it.
    ///
    /// The rule belongs here, behind the tabs, rather than in an overlay over them. Drawn over the
    /// top it crosses the selected tab as well, which boxes that tab in and leaves the strip
    /// reading as a row of buttons; drawn behind, the selected tab's own opaque fill breaks it, and
    /// that break is what joins the tab to the content below.
    ///
    /// `busy` puts the activity signal on that rule, and it goes in this background rather than in
    /// an overlay for exactly the reason the rule does: the lit rule has to be broken by the
    /// selected tab on the same pixels the rule is broken on, or the tab reads as sitting on top of
    /// a line rather than as part of it. See `ActivityRule`.
    ///
    /// `busy` and no longer `pulsing`, because the signal no longer pulses: it is a crest running
    /// the rule, and a parameter named after a figure that has been replaced is the next reader's
    /// wrong turn. The same rename took `RuleSweep` to `RulePulse` when the light stopped sweeping.
    func tabStripMaterial(busy: Bool = false) -> some View {
        background(alignment: .bottom) {
            if busy { ActivityRule().frame(height: Metrics.hairline * 2) }
        }
    }
}

// MARK: - Reusable chrome

/// A separator drawn at `Metrics.hairline`: one point, which is two physical pixels on Retina and
/// what AppKit's own split view divider has always been. See that constant for why it is not half
/// a point.
struct Hairline: View {
    var axis: Axis = .horizontal
    /// The colour of the rule. `Palette.border` everywhere except where a rule has to meet the
    /// split view's own divider: see `Palette.paneDivider`.
    var ink: Color = Palette.border

    var body: some View {
        Rectangle()
            .fill(ink)
            .frame(
                width: axis == .vertical ? Metrics.hairline : nil,
                height: axis == .horizontal ? Metrics.hairline : nil
            )
    }
}

/// Something the user has to read before pressing, or after it went wrong.
///
/// Here rather than beside the sheet that first drew it: `ProjectSetupSheet` and
/// `StartProjectView` say the same things about the same folders, so a warning worded and tinted
/// two ways would be the same fault the two dialogs were split to avoid.
struct Callout: View {
    enum Tone {
        case warning
        case negative

        var color: Color {
            switch self {
            case .warning: Palette.warning
            case .negative: Palette.negative
            }
        }
    }

    let text: String
    let symbol: String
    let tone: Tone

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.spacingWide) {
            Image(systemName: symbol)
                .font(Typo.caption)
                .foregroundStyle(tone.color)
                .accessibilityHidden(true)
            Text(text)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Metrics.inset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.color.opacity(0.10), in: RoundedRectangle(cornerRadius: Metrics.corner))
    }
}

/// The small rounded label used for tool names, file chips, counts and states.
/// How a whole number is set when it is read rather than calculated with.
///
/// **One rule, because there were two and one of them was wrong.** `DiffStatLabel` worked this out
/// first and wrote it down: a bare count goes through `formatted` rather than `String(value)`, so
/// the digits are the reader's own on a machine that does not use Western ones, and it drops the
/// grouping separator, because a separator on a number nobody is going to add up is noise.
/// `CountLabel` arrived later and used a plain `.number`, which is the same decision taken the
/// other way by not taking it, and the search panel's chips came out reading "Everything 3.752"
/// on a machine whose separator is a full stop. Four digits that read as a decimal.
///
/// So the style lives here and both of them read it, rather than each holding an opinion about
/// figures. It is not a rule about badges: `DiffStatLabel`'s abbreviated form keeps a separator,
/// `2,8k`, and is right to, because that one is a DECIMAL separator doing real work rather than a
/// thousands separator being decorative.
enum Figures {
    /// A whole number, in the reader's own digits, with no thousands separator.
    static let count = IntegerFormatStyle<Int>.number.grouping(.never)
}

struct Chip: View {
    var text: String
    var systemImage: String?
    var tint: Color = Palette.textSecondary
    var background: Color = Palette.hover
    var monospaced: Bool = false

    @Environment(\.isOnEmphasizedSelection) private var isOnSelection

    var body: some View {
        // A chip carries content, not metadata: the file a tool read, the model a session started
        // on. At 10 it was the smallest thing in the window while saying the most, and it was the
        // one place drawing a raw `.caption2` rather than a rung of the scale.
        HStack(spacing: Metrics.spacingSmall) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(Typo.micro)
                    .imageScale(.small)
            }
            Text(text)
                .font(monospaced ? Typo.codeSmall : Typo.caption)
                .lineLimit(1)
        }
        .foregroundStyle(isOnSelection ? Palette.selectedEmphasizedText : tint)
        .padding(.horizontal, Metrics.chipInsetH)
        .padding(.vertical, Metrics.chipInsetV)
        .background(
            isOnSelection ? Palette.selectedEmphasizedText.opacity(0.2) : background,
            in: RoundedRectangle(cornerRadius: Metrics.cornerSmall)
        )
    }
}

/// A number set beside a control's label, for reading rather than for adding up.
///
/// # It was a filled round, and macOS does not draw one here
///
/// The owner asked for the count "in a round" and got one: a filled capsule inside the chip's own
/// capsule. He then looked at it twice and said the chips do not feel native, that the number
/// touches the border of the thing holding it, and to make it breathe. All three are the same
/// fault. Two nested capsules is a web pill, not a Mac control, and the inner one had nowhere to
/// sit because the outer one is only as tall as its text.
///
/// **A filled round on macOS means unread, not "how many".** Mail draws one in the sidebar for
/// messages you have not read, and a notification badge is the same idiom: it is a thing wanting
/// your attention. A count on a filter is a different sentence, "this is how much pressing me
/// would show", and macOS sets that as a plain trailing number in a quieter ink, which is what a
/// `List` row's own `badge` is and what a segmented control does when it puts a number in its
/// title. So this is that: no fill, no shape, one step quieter than the label beside it.
///
/// # Its width is still reserved, because that complaint was separate and still stands
///
/// The counts change on nearly every keystroke, and a number sized to its own content takes the
/// chip, the row of chips and the eye with it. Three digits of monospaced figures are laid out
/// behind the number and hidden, so one, ten and a hundred are the same width and only a thousand
/// grows. A nought is drawn rather than left out, for the reason `HomeScopeCounts.badge` argues
/// the other way for Home's resting strip and which does not hold here: this only appears while a
/// search is running, where "Transcripts 0" is a real answer and the reason not to press that
/// chip, and a number that disappeared at nought would be a fourth thing moving while somebody
/// types.
struct CountLabel: View {
    var count: Int
    /// Whether the control under it is drawn in the accent, which the ink answers to. Passed
    /// rather than read from `isOnEmphasizedSelection`, because a chip paints its own selection
    /// rather than sitting inside a selected row.
    var isOnSelection = false

    /// What the number is always at least as wide as. Three digits, in figures that are all one
    /// width, so nothing under a thousand moves it. A thousand and over grows it by one digit and
    /// no more, because it is set without a thousands separator: see `Figures.count`.
    private static let reserved = "000"

    var body: some View {
        // Leading, so the digits sit against the label they belong to and the reserved slack falls
        // at the end, inside the capsule where the padding already is. Trailing put a lone "3" two
        // characters away from "Workspaces", reading as a number somebody had left there.
        ZStack(alignment: .leading) {
            Text(verbatim: Self.reserved)
                .monospacedDigit()
                .hidden()
            Text(count, format: Figures.count)
                .monospacedDigit()
                .lineLimit(1)
        }
        .font(Typo.caption)
        // One step quieter than the label it follows, in both states, because it is the label's
        // subordinate rather than a second thing to read.
        .foregroundStyle(
            isOnSelection ? Palette.selectedEmphasizedText.opacity(0.76) : Palette.textTertiary
        )
        .accessibilityHidden(true)
    }
}

/// `+118 -4` as seen next to a workspace in the sidebar.
struct DiffStatLabel: View {
    var additions: Int
    var deletions: Int
    var compact: Bool = false

    @Environment(\.isOnEmphasizedSelection) private var isOnSelection

    var body: some View {
        HStack(spacing: Metrics.spacingSmall) {
            if additions > 0 {
                Text("+\(Self.abbreviate(additions))")
                    .foregroundStyle(isOnSelection ? Palette.selectedEmphasizedText : Palette.positive)
            }
            if deletions > 0 {
                Text("-\(Self.abbreviate(deletions))")
                    .foregroundStyle(
                        isOnSelection
                            ? Palette.selectedEmphasizedText.opacity(0.75)
                            : Palette.negative
                    )
            }
        }
        // One rung, two designs: `compact` is the monospaced form used inside a chip, where the
        // digits have to line up with a filename set in the same face, not a smaller form. It was
        // written as a size step and never was one, because both styles resolved to 10.
        .font(compact ? Typo.codeSmall : Typo.caption)
        .monospacedDigit()
    }

    /// The three styles the counts are set in, composed once rather than per call.
    ///
    /// This label draws two numbers for every changed file in the inspector, and a running agent
    /// rewrites that list every six seconds, so `abbreviate` runs a few hundred times a minute
    /// while nothing the reader can see has moved.
    ///
    /// The plain case is `Figures.count`, which is where the argument for it now lives: this
    /// label made that decision first and `CountLabel` needed the same one, so it is one style
    /// read twice rather than two that can drift.
    private static let thousandsStyle = FloatingPointFormatStyle<Double>.number
        .precision(.fractionLength(1))
    private static let wholeThousandsStyle = FloatingPointFormatStyle<Double>.number
        .precision(.fractionLength(0))
        .grouping(.never)

    /// 2.8k rather than 2793, because the sidebar has no room for the exact number.
    ///
    /// `formatted` rather than `String(format:)`, which is not locale aware: the composer's token
    /// gauge a few inches away already used `formatted`, so on a machine set to a comma decimal
    /// separator one number in this window read `174,0k` and the other `2.8k`.
    static func abbreviate(_ value: Int) -> String {
        if value < 1_000 { return value.formatted(Figures.count) }
        let thousands = Double(value) / 1_000
        return thousands < 10
            ? "\(thousands.formatted(thousandsStyle))k"
            : "\(thousands.formatted(wholeThousandsStyle))k"
    }
}

/// Whether the content is sitting on an emphasized (accent coloured) selection.
///
/// A selected row inverts its text, but a label that hard-codes a colour, such as a green plus
/// count, keeps its own and ends up unreadable on the accent fill. Descendants read this to pick
/// a variant that survives the inversion, which is what AppKit does for secondary text in a
/// selected table row.
private struct OnEmphasizedSelectionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isOnEmphasizedSelection: Bool {
        get { self[OnEmphasizedSelectionKey.self] }
        set { self[OnEmphasizedSelectionKey.self] = newValue }
    }
}

/// Rows in the sidebar and the file list share this hover and selection treatment.
///
/// Selection follows the AppKit convention rather than a single fixed colour: the accent colour
/// only when the window is active, a quiet grey otherwise. A row that stays vivid blue in a
/// background window is one of the clearest tells that an app is not really native.
struct RowBackground: ViewModifier {
    var isSelected: Bool
    var isHovered: Bool
    /// Whether the list this row belongs to has keyboard focus.
    ///
    /// Default false, because most of the lists that draw a selection in this window never take
    /// focus. The inspector's changed files are picked with the pointer while the composer holds
    /// the keyboard, and AppKit's rule for that is the quiet grey, not the accent: the emphasized
    /// fill means "the arrow keys move this", and painting it on a list the arrow keys do not move
    /// is a promise the window does not keep. It was keyed on the window being main instead, which
    /// is why every one of those rows sat in a saturated accent fill all the time.
    ///
    /// The menus over the composer pass true, since they really are driven by the arrow keys.
    var isFocused: Bool = false
    /// Whether this row sits in something that declares a `containerShape`, in which case the
    /// plate is concentric with it. False everywhere else, where a concentric shape with no
    /// container to read falls back to a square.
    var isConcentric: Bool = false

    @Environment(\.controlActiveState) private var activeState

    func body(content: Content) -> some View {
        content
            .background {
                plate
            }
            .foregroundStyle(isEmphasized ? Palette.selectedEmphasizedText : Palette.textPrimary)
            .environment(\.isOnEmphasizedSelection, isEmphasized)
    }

    /// Concentric with the card the row is in, where there is one, and the window's own radius
    /// where there is not. A concentric shape outside a declared container falls back to a square,
    /// which is what put a square hover plate in the transcript.
    /// A rounded rectangle, inset from the edges of whatever holds the row.
    ///
    /// `ConcentricRectangle` was tried here twice and failed both ways: with no container
    /// declaring a shape it falls back to a square, and once the plate is inset from the
    /// container it stops reading the container at all and falls back to a square again. A fixed
    /// radius is what is left, and it is the one every other plate in this window takes.
    private var plate: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(fill)
            .padding(.horizontal, inset)
            .padding(.vertical, isConcentric ? 1 : 0)
    }

    /// How far the plate sits in from the card that holds it.
    private var inset: CGFloat { isConcentric ? Metrics.spacingSmall : 0 }

    /// The container's radius less the gap to it, which is the concentricity rule written out:
    /// a card at twelve holding a plate four points in wants eight, not twelve. At twelve the
    /// curve was wider than the space it had and the plate read as a rectangle with cut corners.
    private var radius: CGFloat {
        isConcentric ? Metrics.corner - inset : Metrics.corner
    }

    private var isEmphasized: Bool {
        isSelected && isFocused && activeState != .inactive
    }

    private var fill: Color {
        if isSelected {
            return isEmphasized ? Palette.selectedEmphasized : Palette.selected
        }
        return isHovered ? Palette.hover : .clear
    }
}

extension View {
    func rowBackground(
        isSelected: Bool, isHovered: Bool, isFocused: Bool = false, isConcentric: Bool = false
    ) -> some View {
        modifier(
            RowBackground(
                isSelected: isSelected, isHovered: isHovered,
                isFocused: isFocused, isConcentric: isConcentric
            )
        )
    }

    /// Tracks hover without each call site needing its own @State.
    func onHoverChange(_ handler: @escaping (Bool) -> Void) -> some View {
        onHover(perform: handler)
    }
}

// MARK: - Link buttons

extension View {
    /// A `Button` that reads as a link, in Unified Dev's teal rather than the system accent.
    ///
    /// `.linkButton()` alone draws system blue: measured `#2B66D3` on this machine, and
    /// whatever the user picked in Appearance on anyone else's. Several of these sit in the
    /// transcript inches from prose links that `Palette.linkNSColor` already paints teal, so the
    /// same word rendered two colours depending on whether it was markdown or a control.
    ///
    /// A modifier rather than a note in a review, because there are eleven call sites and the
    /// twelfth is the one that would be missed.
    func linkButton() -> some View {
        buttonStyle(.link).tint(Palette.link)
    }
}

// MARK: - Focus rings

extension ControlActiveState {
    /// Whether a focus ring drawn under this state should be visible at all.
    ///
    /// AppKit draws a focus ring only in the key window, and every hand-drawn ring in Unified Dev was
    /// drawing one in every window at once: with five workspaces open, four of them showed a lit
    /// composer while the fifth was the one actually taking the keys.
    ///
    /// Named here rather than written out at each ring, because there are five of them and the
    /// sixth is the one that would be missed.
    var showsFocusRing: Bool { self != .inactive }
}
