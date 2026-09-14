import Foundation

/// Every colour Unified Dev states as a number, in the one place a test can read them.
///
/// `Palette` in the app target is what the window draws with, and it is `Color` and `NSColor`,
/// which is exactly why the values could not be checked: `Tests/CoreTests` depends on
/// `Core` alone, so a ratio written in a doc comment beside a `Color` was a claim nothing
/// could ever contradict. Several of those claims were wrong and one of them said so.
///
/// So the numbers live here and `Palette` reads them. Nothing about how a colour is resolved
/// moved: the light and dark members, the appearance switch, and every doc comment explaining why
/// a hue was chosen are all still next to the `Color` in `Theme.swift`. What is here is the pair
/// of integers and nothing else, which is all `Contrast` needs and all a table test can assert.
///
/// See `PaletteContrastTests`, which is the point of this file: it walks every pair against every
/// ground it is drawn on and fails the build when one of them stops clearing its floor.
public enum PaletteInk {
    /// A colour's two members. There is no third: `Palette.dynamicNSColor` picks between exactly
    /// these two, and a value that is one colour in both appearances says so by repeating itself,
    /// the way `accentFill` and `mergedFill` do.
    public struct Pair: Sendable, Hashable {
        public let light: UInt32
        public let dark: UInt32

        public init(light: UInt32, dark: UInt32) {
            self.light = light
            self.dark = dark
        }

        /// The member drawn in one appearance, so a test can walk both without a switch at every
        /// call site.
        public func member(dark isDark: Bool) -> UInt32 { isDark ? dark : light }
    }

    /// Everything below except `accent` and `accentFill` is now a measured system colour, not a
    /// hand-mixed one: `Core` has no AppKit to ask directly, so `PaletteContrastTests` still needs
    /// a plain number, and these are that colour's own resolved value in each appearance rather
    /// than an invented one. See `Palette` in the app target for the live `NSColor`/`Color` each
    /// one actually resolves through, and the probe that read these off `NSAppearance` is recorded
    /// there too.
    ///
    /// `windowBackground`, `surface`, `surfaceRaised` and `surfaceSunken` are one value under
    /// Tahoe's own tokens (`windowBackgroundColor` / `controlBackgroundColor`), which is the
    /// system's own answer and not a regression: four names still exist because call sites mean
    /// different things by them, even though the paint is the same.
    public static let windowBackground = Pair(light: 0xFFFFFF, dark: 0x1E1E1E)
    public static let surface = Pair(light: 0xFFFFFF, dark: 0x1E1E1E)
    public static let surfaceRaised = Pair(light: 0xFFFFFF, dark: 0x1E1E1E)
    public static let surfaceSunken = Pair(light: 0xFFFFFF, dark: 0x1E1E1E)
    /// `unemphasizedSelectedContentBackgroundColor`.
    public static let selected = Pair(light: 0xDCDCDC, dark: 0x464646)
    /// `separatorColor`, composited over the window background above.
    public static let border = Pair(light: 0xE6E6E6, dark: 0x343434)
    /// `tertiaryLabelColor`, composited over the window background above. This is the system's own
    /// third rung, and it measures under the text floor on this ground: see
    /// `PaletteContrastTests.textClearsItsFloor`, which says so rather than hiding it.
    public static let textTertiary = Pair(light: 0xBDBDBD, dark: 0x565656)
    public static let accent = Pair(light: 0x50008F, dark: 0xBB66FF)
    /// Violet, `#7C3AED`, which is the brand's own and not a system colour: AppKit has
    /// `systemPurple` at `#CB30E0`, magenta enough to read as pink beside our own marks, and
    /// `systemIndigo` at `#6155F5`, nearly blue. This is the value Hodos carries in its own
    /// `AccentColor`, so the two apps are one violet.
    ///
    /// The dark member is a rung lighter, `#8B5CF6`, and that is a measurement rather than a
    /// preference: `#7C3AED` comes out at 2.93 to 1 against the dark surface, under the 3.0 floor
    /// a mark has to clear. See `PaletteContrastTests`.
    public static let accentFill = Pair(light: 0x7C3AED, dark: 0x8B5CF6)
    /// `systemRed`.
    public static let negative = Pair(light: 0xFF383C, dark: 0xFF4245)
    /// `systemRed`, at 85 percent over the window background, composited to a plain opaque pair.
    /// This is a derived tint rather than a system colour of its own, so it is tuned rather than
    /// reported: 75 percent read as a wash rather than a quieter stop, at 2.79 and 3.24 to 1, under
    /// the 3.0 mark floor in light. 85 clears it in both. See `Palette.stop`.
    public static let stop = Pair(light: 0xFF5659, dark: 0xDD3D3F)
    /// `systemOrange`.
    public static let warning = Pair(light: 0xFF8D28, dark: 0xFF9230)
    /// The brand violet, `#7C3AED`. It was `systemBlue`, and blue is the one hue in this window
    /// that belongs to nothing: the marks for working, the pulse and the waiting line all read as
    /// a second accent beside the real one.
    public static let running = Pair(light: 0x7C3AED, dark: 0x8B5CF6)
    /// `systemPurple`.
    public static let merged = Pair(light: 0xCB30E0, dark: 0xDB34F2)
    /// `systemPurple`, darkened until white clears the text floor on it in both appearances: the
    /// light member of the pair above measures under AA for white, which `mergedFill` cannot do
    /// and still carry the Archive button's label. See `PaletteContrastTests.fillsCarryTheirLabel`.
    public static let mergedFill = Pair(light: 0x9A1FAC, dark: 0x9A1FAC)
    public static let diffPositive = Pair(light: 0x28CD41, dark: 0x30D158)
    /// `systemGreen`. Decoupled from `accent`: the brand purple no longer doubles as the app's one
    /// "healthy" hue, so a passing check and a link are no longer the same colour by coincidence.
    public static let positive = Pair(light: 0x34C759, dark: 0x30D158)
    public static let synKeyword = Pair(light: 0x9B2393, dark: 0xD08EE0)
    public static let synType = Pair(light: 0x0B7285, dark: 0x5BC8DB)
    public static let synString = Pair(light: 0xC0392B, dark: 0xE8846E)
    public static let synNumber = Pair(light: 0x1C6FBB, dark: 0x7FB3F0)
    /// The dark member moved from `#818189` (4.31 to 1) to `#8B8B93` (4.93) when `surface`'s dark
    /// member moved from a hand-mixed `#181818` to the system's own `windowBackgroundColor`,
    /// `#1E1E1E`: a slightly lighter ground that put the untouched comment ink under the text
    /// floor. The syntax ramp itself stays the app's own tuned pairs, per the instruction that
    /// reading semantics are kept; only this one member was retuned, along its own hue, to hold the
    /// floor against the new ground under it.
    public static let synComment = Pair(light: 0x6D7879, dark: 0x8B8B93)
    public static let synFunction = Pair(light: 0x2F5FD0, dark: 0x89AFF5)
    public static let synVariable = Pair(light: 0x6A3FB5, dark: 0xB49BF0)
    public static let synAttribute = Pair(light: 0x8A6A00, dark: 0xD9B65C)
    public static let synOperator = Pair(light: 0x5A5A60, dark: 0xA8A8B0)

    /// What AppKit derives from `accentFill` for the ground under selected text, measured rather
    /// than chosen.
    ///
    /// This is the one pair here Unified Dev does not draw. `Palette.textSelection` is
    /// `selectedTextBackgroundColor` and stays semantic, because the selection has to follow Full
    /// Keyboard Access and the key window the way the system's does. What changed is what the
    /// system derives it FROM: `NSAccentColorName` in the bundle's Info.plist points
    /// `controlAccentColor` at the `AccentColor` set in Assets.car, which carries `accentFill`, and
    /// every colour AppKit computes off the accent moves with it. Before that the selection was
    /// `#B3D7FF` and `#3F638B`, the system blue's, while the row selection two hundred points away
    /// was Unified Dev's, which is the two-blues complaint at its most visible.
    ///
    /// A derived colour is exactly the kind of claim that used to go in a doc comment and never be
    /// checked again, so it is a number here instead: read off `NSColor.selectedTextBackgroundColor`
    /// in a bundle carrying this accent, in both appearances, and asserted by
    /// `PaletteContrastTests`. It sits BEHIND text, so the day somebody retunes `accentFill` up the
    /// ramp, the test says whether the selection still carries a label rather than leaving it to be
    /// noticed while dragging over a paragraph.
    ///
    /// It only describes a Mac left on the Multicolour default. A user who has chosen an accent in
    /// System Settings gets their own derivation and this pair is not what is on screen, which is
    /// the same caveat `Palette.accent` carries about the whole mechanism.
    public static let accentTextSelection = Pair(light: 0xBAD6DF, dark: 0x46626B)

    /// The ink AppKit puts on that ground: `selectedTextColor`, which resolves to plain black and
    /// plain white rather than to `labelColor`. Stated so the assertion measures the pair that is
    /// really on screen instead of assuming the text colour.
    public static let selectedTextInk = Pair(light: 0x000000, dark: 0xFFFFFF)
}
