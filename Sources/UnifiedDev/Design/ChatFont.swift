import AppKit
import CoreText
import SwiftUI
import Core

struct ChatFont: Hashable, Sendable {
    let rawValue: String
    let face: ChatFace
    let inlineCodeScale: CGFloat

    init(rawValue: String) {
        let id = ChatFontCatalogue.canonicalID(rawValue)
        let resolved = ChatFontCatalogue.resolve(id, installed: Self.installedFamilies)
        self.rawValue = id
        face = resolved
        inlineCodeScale = CGFloat(
            ChatFontCatalogue.inlineCodeScale(
                faceXHeight: Double(Self.nsFont(for: resolved, size: Self.metricSize).xHeight),
                monoXHeight: Double(Self.monoXHeight)
            )
        )
    }

    static let defaultsKey = ChatFontCatalogue.defaultsKey
    static let standardID = ChatFontCatalogue.standardID

    static let standard = ChatFont(rawValue: standardID)

    static let system = standard

    var isSystemFace: Bool { face == .system }

    static func familyChoices(keeping selected: String) -> [String] {
        ChatFontCatalogue.families(from: availableFamilies, keeping: selected)
    }

    static func summary(for stored: String) -> String {
        ChatFontCatalogue.summary(for: stored, installed: installedFamilies)
    }

    func font(size: CGFloat, weight: Font.Weight) -> Font {
        switch face {
        case .system:
            .system(size: size, weight: weight)
        case .serif:
            .system(size: size, weight: weight, design: .serif)
        case .family(let name):
            .custom(name, fixedSize: size).weight(weight)
        }
    }

    func nsFont(size: CGFloat) -> NSFont { Self.nsFont(for: face, size: size) }

    private static func nsFont(for face: ChatFace, size: CGFloat) -> NSFont {
        let system = NSFont.systemFont(ofSize: size)
        switch face {
        case .system:
            return system
        case .serif:
            return system.fontDescriptor.withDesign(.serif)
                .flatMap { NSFont(descriptor: $0, size: size) } ?? system
        case .family(let name):
            let descriptor = NSFontDescriptor(fontAttributes: [.family: name])
            return NSFont(descriptor: descriptor, size: size) ?? system
        }
    }

    private static let metricSize: CGFloat = 13

    private static let monoXHeight = NSFont.monospacedSystemFont(
        ofSize: metricSize, weight: .regular
    ).xHeight

    private static let availableFamilies: [String] =
        CTFontManagerCopyAvailableFontFamilyNames() as? [String] ?? []

    private static let installedFamilies = Set(availableFamilies)

    static func == (lhs: ChatFont, rhs: ChatFont) -> Bool { lhs.rawValue == rhs.rawValue }

    func hash(into hasher: inout Hasher) { hasher.combine(rawValue) }
}

extension EnvironmentValues {
    @Entry var chatFont: ChatFont = .system
}
