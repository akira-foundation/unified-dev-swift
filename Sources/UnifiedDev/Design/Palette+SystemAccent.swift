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
        var accent = AccentInk(accent: PaletteInk.multicolorAccent.member(dark: isDark), isDark: isDark)
        appearance.performAsCurrentDrawingAppearance {
            if let resolved = NSColor.controlAccentColor.usingColorSpace(.sRGB) {
                accent = AccentInk(
                    red: Double(resolved.redComponent),
                    green: Double(resolved.greenComponent),
                    blue: Double(resolved.blueComponent),
                    isDark: isDark
                )
            }
        }
        return accent
    }

    static func colour(_ pick: @escaping @Sendable (AccentInk) -> NSColor) -> NSColor {
        NSColor(name: nil) { appearance in pick(ink(for: appearance)) }
    }
}
