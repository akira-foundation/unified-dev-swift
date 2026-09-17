import SwiftUI
import AppKit
import Core

struct RepoIcon: View {
    var name: String
    var accent: String?
    var size: CGFloat = Metrics.repoIcon
    var artwork: RepoArtwork?

    @Environment(\.isOnEmphasizedSelection) private var isOnSelection

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(name: String, accent: String?, size: CGFloat = Metrics.repoIcon) {
        self.name = name
        self.accent = accent
        self.size = size
    }

    init(repo: Repo?, size: CGFloat = Metrics.repoIcon) {
        self.init(name: repo?.name ?? "", accent: repo?.accent, size: size)
        artwork = repo.flatMap(RepoIconArt.artwork(for:))
        artworkKey = repo?.hasIcon == true ? repo?.iconPath : nil
    }

    private var artworkKey: String?

    var body: some View {
        ZStack {
            monogram.opacity(artwork == nil ? 1 : 0)
            if let artwork { picture(artwork) }
        }
        .animation(reduceMotion ? nil : Motion.arrival, value: artworkKey)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
    }

    private func picture(_ artwork: RepoArtwork) -> some View {
        Image(nsImage: artwork.image)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(shape)
            .overlay {
                if artwork.isFullBleed {
                    shape.strokeBorder(borderInk, lineWidth: Metrics.hairline / 2)
                }
            }
            .accessibilityHidden(true)
    }

    private var borderInk: Color {
        isOnSelection ? Palette.selectedEmphasizedText.opacity(0.35) : Palette.textPrimary.opacity(0.15)
    }

    private var monogram: some View {
        shape
            .fill(fill)
            .overlay {
                Text(RepoMonogram.initials(for: name))
                    .font(.system(size: (size * 0.55).rounded(), weight: .semibold, design: .rounded))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 1)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var tint: Color {
        guard let accent else { return Palette.textTertiary }
        return RepoAccent.tint(for: accent)
    }

    private var fill: Color {
        isOnSelection ? Palette.selectedEmphasizedText.opacity(0.22) : tint
    }

    private var ink: Color {
        isOnSelection ? Palette.selectedEmphasizedText : contrastingInk
    }

    private var contrastingInk: Color {
        guard let accent else { return Palette.textPrimary }
        return RepoAccent.ink(for: accent)
    }
}

@MainActor
private enum RepoAccent {
    private static var inks: [String: Color] = [:]
    private static var tints: [String: Color] = [:]

    static func tint(for hex: String) -> Color {
        if let known = tints[hex] { return known }
        let tint = Color(hexString: hex)
        tints[hex] = tint
        return tint
    }

    static func ink(for hex: String) -> Color {
        if let known = inks[hex] { return known }
        let parsed = HexColor(hex: hex) ?? HexColor(red: 0x4C, green: 0x8D, blue: 0xF6)
        let packed = UInt32(parsed.red) << 16 | UInt32(parsed.green) << 8 | UInt32(parsed.blue)
        let ink: Color = Contrast.relativeLuminance(of: packed) > 0.35 ? .black : .white
        inks[hex] = ink
        return ink
    }
}
