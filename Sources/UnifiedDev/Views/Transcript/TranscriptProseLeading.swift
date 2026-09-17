import AppKit
import SwiftUI
import Core

extension TranscriptLayout {
    @MainActor
    static func proseLeading(
        _ rung: ScaledFont, scale: CGFloat, face: ChatFont, lineHeight: ChatLineHeight
    ) -> CGFloat {
        proseLeading(rung, scale: scale, face: face, ratio: lineHeight.ratio)
    }

    @MainActor
    static func proseLeading(
        _ rung: ScaledFont, scale: CGFloat, face: ChatFont, ratio: Double
    ) -> CGFloat {
        let font = rung.resolvedNSFont(scale: scale, face: face)
        return CGFloat(TextLeading.overPointSize(
            lineHeight: Double(lineBox(of: font)),
            pointSize: Double(font.pointSize),
            ratio: ratio
        ))
    }

    @MainActor
    static func listItemGap(
        _ rung: ScaledFont, scale: CGFloat, face: ChatFont, lineHeight: ChatLineHeight,
        tight: Bool, prose: Bool = false
    ) -> CGFloat {
        let font = rung.resolvedNSFont(scale: scale, face: face)
        if prose {
            return CGFloat(ListLeading.betweenProseItems(
                tight: tight, lineHeight: Double(lineBox(of: font)),
                pointSize: Double(font.pointSize), ratio: lineHeight.ratio
            ))
        }
        return CGFloat(ListLeading.betweenItems(
            tight: tight,
            lineHeight: Double(lineBox(of: font)),
            pointSize: Double(font.pointSize),
            ratio: lineHeight.listRatio
        ))
    }

    @MainActor
    static func codeLeading(_ rung: ScaledFont, scale: CGFloat, face: ChatFont) -> CGFloat {
        CGFloat(TextLeading.overLineBox(
            lineHeight: Double(lineBox(of: rung.resolvedNSFont(scale: scale, face: face)))
        ))
    }

    @MainActor
    private static func lineBox(of font: NSFont) -> CGFloat {
        if let held = lineBoxes[font] { return held }
        let measured = leadingLayout.defaultLineHeight(for: font)
        lineBoxes[font] = measured
        return measured
    }

    @MainActor private static var lineBoxes: [NSFont: CGFloat] = [:]
    @MainActor private static let leadingLayout = NSLayoutManager()
}

extension View {
    func proseLeading(_ rung: ScaledFont = Typo.body) -> some View {
        modifier(ProseLeadingModifier(rung: rung))
    }
}

private struct ProseLeadingModifier: ViewModifier {
    let rung: ScaledFont

    @Environment(\.fontScale) private var scale
    @Environment(\.chatFont) private var face
    @Environment(\.chatLineHeight) private var lineHeight

    func body(content: Content) -> some View {
        content.lineSpacing(
            TranscriptLayout.proseLeading(rung, scale: scale, face: face, lineHeight: lineHeight)
        )
    }
}

extension EnvironmentValues {
    @Entry var chatLineHeight: ChatLineHeight = .defaultChoice
}
