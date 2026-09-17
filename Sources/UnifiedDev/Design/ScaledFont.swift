import SwiftUI
import AppKit

struct ScaledFont: Hashable, Sendable {
    private let unscaled: Font
    private let style: Font.TextStyle
    private let weight: Font.Weight?
    private let design: Font.Design

    init(_ style: Font.TextStyle, weight: Font.Weight? = nil, design: Font.Design = .default) {
        self.style = style
        self.weight = weight
        self.design = design
        let base = Font.system(style, design: design)
        unscaled = weight.map { base.weight($0) } ?? base
    }

    func resolved(scale: CGFloat, face: ChatFont = .system) -> Font {
        let wantsFace = !face.isSystemFace && design != .monospaced
        guard scale != 1 || wantsFace else { return unscaled }
        let base = NSFont.preferredFont(forTextStyle: style.appKitStyle)
        let size = (base.pointSize * scale).rounded()
        let resolvedWeight = weight ?? base.systemWeight
        guard wantsFace else {
            return Font.system(size: size, weight: resolvedWeight, design: design)
        }
        return face.font(size: size, weight: resolvedWeight)
    }

    func resolvedNSFont(scale: CGFloat, face: ChatFont = .system) -> NSFont {
        let base = NSFont.preferredFont(forTextStyle: style.appKitStyle)
        let size = (base.pointSize * scale).rounded()
        guard design != .monospaced else {
            return .monospacedSystemFont(ofSize: size, weight: (weight ?? base.systemWeight).appKitWeight)
        }
        guard !face.isSystemFace else {
            return .systemFont(ofSize: size, weight: (weight ?? base.systemWeight).appKitWeight)
        }
        return face.nsFont(size: size)
    }

    func monospacedCompanionNSFont(scale: CGFloat, face: ChatFont = .system) -> NSFont {
        let base = NSFont.preferredFont(forTextStyle: style.appKitStyle)
        let size = (base.pointSize * scale * face.inlineCodeScale).rounded()
        return .monospacedSystemFont(ofSize: size, weight: (weight ?? base.systemWeight).appKitWeight)
    }

    func monospacedCompanion(scale: CGFloat, face: ChatFont = .system) -> Font {
        let base = NSFont.preferredFont(forTextStyle: style.appKitStyle)
        let size = (base.pointSize * scale * face.inlineCodeScale).rounded()
        return Font.system(size: size, weight: weight ?? base.systemWeight, design: .monospaced)
    }
}

extension Font.Weight {
    var appKitWeight: NSFont.Weight {
        switch self {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .regular
        }
    }
}

extension View {
    func font(_ font: ScaledFont) -> some View {
        modifier(ScaledFontModifier(font: font))
    }
}

private struct ScaledFontModifier: ViewModifier {
    let font: ScaledFont

    @Environment(\.fontScale) private var scale
    @Environment(\.chatFont) private var face

    func body(content: Content) -> some View {
        content.font(font.resolved(scale: scale, face: face))
    }
}

extension EnvironmentValues {
    @Entry var fontScale: CGFloat = 1
}

private extension Font.TextStyle {
    var appKitStyle: NSFont.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .body: .body
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        default: .body
        }
    }
}

private extension NSFont {
    var systemWeight: Font.Weight {
        let traits = fontDescriptor.object(forKey: .traits) as? [NSFontDescriptor.TraitKey: Any]
        let value = traits?[.weight] as? CGFloat ?? 0
        return switch value {
        case ..<(-0.4): .ultraLight
        case ..<(-0.2): .thin
        case ..<(-0.05): .light
        case ..<0.15: .regular
        case ..<0.27: .medium
        case ..<0.35: .semibold
        case ..<0.5: .bold
        case ..<0.7: .heavy
        default: .black
        }
    }
}
