import SwiftUI
import AppKit
import Core

struct ChipRemoveButton: View {
    var diameter: CGFloat
    var label: String
    var action: @MainActor () -> Void

    @State private var isHovered = false

    @Environment(\.isOnEmphasizedSelection) private var isOnSelection

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: ChipRemoveMark.glyphPointSize(diameter: diameter), weight: .bold))
                .foregroundStyle(ink)
                .frame(width: diameter, height: diameter)
                .background(plate, in: Circle())
                .overlay {
                    Circle().strokeBorder(ring, lineWidth: Metrics.outline)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHoverChange { isHovered = $0 }
        .help(label)
        .accessibilityLabel(label)
    }

    private var ink: Color {
        isOnSelection ? Palette.selectedEmphasizedText : Palette.textPrimary
    }

    private var plate: Color {
        guard isOnSelection else {
            return isHovered ? Palette.hover : Palette.surface
        }
        return Palette.selectedEmphasizedText
            .opacity(isHovered ? ChipRemoveMark.emphasisPlateHovered : ChipRemoveMark.emphasisPlate)
    }

    private var ring: Color {
        isOnSelection
            ? Palette.selectedEmphasizedText.opacity(ChipRemoveMark.emphasisRing)
            : Palette.border
    }
}

@MainActor
enum ChipRemoveImage {
    static func of(
        diameter: CGFloat, ink: NSColor, plate: NSColor, border: NSColor, label: String
    ) -> NSImage? {
        let size = NSImage.SymbolConfiguration(
            pointSize: ChipRemoveMark.glyphPointSize(diameter: diameter), weight: .bold
        )
        let colour = NSImage.SymbolConfiguration(paletteColors: [ink])
        guard let glyph = NSImage(systemSymbolName: "xmark", accessibilityDescription: label)?
            .withSymbolConfiguration(size.applying(colour)) else { return nil }

        let outline = Metrics.outline
        let image = NSImage(size: NSSize(width: diameter, height: diameter), flipped: false) { rect in
            let disc = NSBezierPath(ovalIn: rect.insetBy(dx: outline / 2, dy: outline / 2))
            plate.setFill()
            disc.fill()
            border.setStroke()
            disc.lineWidth = outline
            disc.stroke()

            let glyphSize = glyph.size
            glyph.draw(
                in: NSRect(
                    x: rect.midX - glyphSize.width / 2,
                    y: rect.midY - glyphSize.height / 2,
                    width: glyphSize.width,
                    height: glyphSize.height
                ),
                from: .zero,
                operation: .sourceOver,
                fraction: 1
            )
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = label
        return image
    }
}
