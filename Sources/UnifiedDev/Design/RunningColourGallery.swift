import SwiftUI
import Core

struct RunningColourGallery: View {
    private static let states: [Mark] = [
        Mark(status: .running, name: "Working"),
        Mark(status: .checksPassed, name: "Checks passed"),
        Mark(status: .checksRunning, name: "Checks running"),
        Mark(status: .checksFailing, name: "Checks failing"),
        Mark(status: .merged, name: "Merged"),
        Mark(status: .clean, name: "No changes"),
    ]

    private struct Mark: Identifiable {
        let status: WorkspaceStatus
        let name: String
        var id: WorkspaceStatus { status }
    }

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Running, against what it sits beside")
                    .font(Typo.title)
                Text("What the busy mark has to be told from, and the hues they are drawn in.")
                    .font(Typo.label)
                    .foregroundStyle(Palette.textSecondary)
            }

            column
            enlarged
            elsewhere
            swatches
        }
        .padding(Metrics.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.surface)
    }

    private var column: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Down the sidebar, at 260 points")
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)
            VStack(spacing: 0) {
                ForEach(Self.states) { mark in
                    HStack(spacing: Metrics.spacing) {
                        WorkspaceStatusGlyph(status: mark.status)
                        Text(mark.name)
                            .font(Typo.body)
                            .foregroundStyle(Palette.textPrimary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .frame(width: Metrics.sidebarWidth, height: 32)
                }
            }
            .background(Palette.controlStrip)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }

    private var enlarged: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("The same marks, six times")
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)
            HStack(alignment: .top, spacing: 24) {
                ForEach(Self.states) { mark in
                    VStack(spacing: 6) {
                        WorkspaceStatusGlyph(status: mark.status)
                            .scaleEffect(6, anchor: .center)
                            .frame(width: Metrics.glyph * 6, height: Metrics.glyph * 6)
                            .background(Palette.surfaceSunken)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Text(mark.name)
                            .font(Typo.micro)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
            }
        }
    }

    private var elsewhere: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("On a tab, on the rule under the strip, and above a user's own message")
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)
            Text("Held still: what Reduce Motion draws, and the only figure a render can photograph.")
                .font(Typo.micro)
                .foregroundStyle(Palette.textSecondary)

            HStack(spacing: 10) {
                tab { ActivityDot(isActive: true) }
                tab { WorkspaceStatusGlyph(status: .checksPassed) }
                Spacer(minLength: 0)
            }

            ZStack(alignment: .bottom) {
                Palette.controlStrip
                Hairline()
                ActivityRuleFigure(variant: .crest, isMoving: false)
            }
            .frame(width: Self.ruleWidth, height: 26)

            bubble
        }
    }

    private var bubble: some View {
        HStack {
            Spacer(minLength: 0)
            Text("Have another look at the transcript stutter")
                .font(Typo.body)
                .foregroundStyle(Palette.textInverted)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Palette.accentFill, in: RoundedRectangle(cornerRadius: 12))
        }
        .frame(width: Self.ruleWidth)
    }

    private static let ruleWidth: CGFloat = 760

    private func tab<Content: View>(@ViewBuilder mark: () -> Content) -> some View {
        HStack(spacing: Metrics.spacingSmall) {
            mark()
            Text("Chat")
                .font(Typo.label)
                .foregroundStyle(Palette.textPrimary)
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(Palette.surfaceSunken)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var swatches: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("The hues, in this appearance")
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)
            HStack(spacing: 12) {
                swatch("running", Palette.running, PaletteInk.running)
                swatch("positive", Palette.positive, PaletteInk.positive)
                swatch("warning", Palette.warning, PaletteInk.warning)
                swatch("negative", Palette.negative, PaletteInk.negative)
                swatch("merged", Palette.merged, PaletteInk.merged)
                swatch("textTertiary", Palette.textTertiary, PaletteInk.textTertiary)
                swatch("multicolorAccent", Palette.dynamic(PaletteInk.multicolorAccent), PaletteInk.multicolorAccent)
            }
        }
    }

    private func swatch(_ name: String, _ colour: Color, _ ink: PaletteInk.Pair) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(colour)
                .frame(width: 96, height: 44)
            Text(name)
                .font(Typo.micro)
                .foregroundStyle(Palette.textSecondary)
            Text(Self.hex(ink.member(dark: colorScheme == .dark)))
                .font(Typo.codeTiny)
                .foregroundStyle(Palette.textTertiary)
        }
    }

    private static func hex(_ value: UInt32) -> String {
        let digits = String(value, radix: 16, uppercase: true)
        return "#" + String(repeating: "0", count: max(0, 6 - digits.count)) + digits
    }
}

extension Gallery {
    static let runningColour = Gallery(
        name: "running-colour",
        title: "Running, against what it sits beside",
        size: CGSize(width: 900, height: 1100),
        needsFocus: false,
        view: { _ in AnyView(RunningColourGallery()) }
    )
}
