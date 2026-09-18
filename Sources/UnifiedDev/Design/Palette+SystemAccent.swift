import SwiftUI
import AppKit
import Core

extension Palette {
    static let accent = Color(nsColor: accentNSColor)

    static let accentNSColor = SystemAccent.colour { NSColor(rgb: $0.ink) }

    static let accentFill = controlAccent

    static let onAccentFill = Color(nsColor: SystemAccent.colour { NSColor(rgb: $0.onFill) })

    static func accent(beside meanings: [PaletteMeaning]) -> Color {
        Color(nsColor: SystemAccent.colour { ink in
            ink.stepsAside(beside: meanings) ? .labelColor : NSColor(rgb: ink.ink)
        })
    }
}

enum SystemAccent {
    static func ink(for appearance: NSAppearance) -> AccentInk {
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        var accent = PaletteInk.multicolorAccent.member(dark: isDark)
        appearance.performAsCurrentDrawingAppearance {
            if let resolved = NSColor.controlAccentColor.usingColorSpace(.sRGB) {
                accent = packed(resolved)
            }
        }
        return AccentInk(accent: accent, isDark: isDark)
    }

    static func colour(_ pick: @escaping @Sendable (AccentInk) -> NSColor) -> NSColor {
        NSColor(name: nil) { appearance in pick(ink(for: appearance)) }
    }

    private static func packed(_ colour: NSColor) -> UInt32 {
        [colour.redComponent, colour.greenComponent, colour.blueComponent].reduce(UInt32(0)) { sum, component in
            (sum << 8) | UInt32((min(max(component, 0), 1) * 255).rounded())
        }
    }
}
