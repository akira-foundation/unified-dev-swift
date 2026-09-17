import SwiftUI
import Core

struct ActivityRuleGallery: View {
    private static let columnWidth: CGFloat = 760
    private static let narrowWidth: CGFloat = 380

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Activity rule")
                    .font(Typo.title)
                Text("What the line under the tab strip says while an agent is working.")
                    .font(Typo.label)
                    .foregroundStyle(Palette.textSecondary)
            }

            ForEach(BusyRuleVariant.allCases, id: \.self) { variant in
                section(variant)
            }

            beside
            enlarged
            narrow
            twoSegments
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func section(_ variant: BusyRuleVariant) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(variant.title)
                    .font(Typo.label)
                if variant == .live {
                    Chip(text: "In the window")
                }
            }
            Text(variant.note)
                .font(Typo.micro)
                .foregroundStyle(Palette.textSecondary)

            strip(variant, isMoving: true, caption: "Working")
            strip(variant, isMoving: false, caption: "Reduce Motion")
        }
    }

    private func strip(
        _ variant: BusyRuleVariant,
        isMoving: Bool,
        caption: String,
        width: CGFloat = ActivityRuleGallery.columnWidth
    ) -> some View {
        HStack(alignment: .bottom, spacing: 10) {
            ZStack(alignment: .bottom) {
                Palette.controlStrip
                Hairline()
                ActivityRuleFigure(variant: variant, isMoving: isMoving)
            }
            .frame(width: width, height: 26)

            Text(caption)
                .font(Typo.micro)
                .foregroundStyle(Palette.textTertiary)
        }
    }

    private var beside: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Above a user's message")
                .font(Typo.label)
            strip(.live, isMoving: true, caption: "Working")
            HStack {
                Spacer(minLength: 0)
                Text("Have another look at the transcript stutter")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textInverted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Palette.accentFill, in: RoundedRectangle(cornerRadius: 12))
            }
            .frame(width: ActivityRuleGallery.columnWidth)
        }
    }

    private var enlarged: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("The crest, four times, held still")
                .font(Typo.label)
            Text("Head at the trailing edge, tail behind it. Direction, in one frame.")
                .font(Typo.micro)
                .foregroundStyle(Palette.textSecondary)
            ZStack(alignment: .bottom) {
                Palette.controlStrip
                ActivityRuleFigure(variant: .crest, isMoving: false)
                    .frame(width: BusyCrest.length, height: BusyCrest.thickness)
                    .scaleEffect(4, anchor: .bottom)
                    .frame(width: BusyCrest.length * 4, height: BusyCrest.thickness * 4)
            }
            .frame(width: ActivityRuleGallery.columnWidth, height: 40)
        }
    }

    private var narrow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("A narrow column")
                .font(Typo.label)
            Text("380 points against a crest of 190. The tail clips; the head does not.")
                .font(Typo.micro)
                .foregroundStyle(Palette.textSecondary)
            strip(
                .live, isMoving: true, caption: "Working",
                width: ActivityRuleGallery.narrowWidth
            )
            strip(
                .live, isMoving: false, caption: "Reduce Motion",
                width: ActivityRuleGallery.narrowWidth
            )
        }
    }

    private var twoSegments: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What it did with the inspector's half lit")
                .font(Typo.label)
            Text("One period, two lengths, two speeds. Reported as two bubbles, and deleted.")
                .font(Typo.micro)
                .foregroundStyle(Palette.textSecondary)
            HStack(alignment: .bottom, spacing: 0) {
                segment(width: ActivityRuleGallery.columnWidth - ActivityRuleGallery.narrowWidth)
                Rectangle()
                    .fill(Palette.border)
                    .frame(width: Metrics.hairline, height: 26)
                segment(width: ActivityRuleGallery.narrowWidth)
            }
        }
    }

    private func segment(width: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Palette.controlStrip
            Hairline()
            ActivityRuleFigure(variant: .live, isMoving: true)
        }
        .frame(width: width, height: 26)
    }
}

extension Gallery {
    static let activityRule = Gallery(
        name: "activity-rule",
        title: "Activity rule",
        size: CGSize(width: 900, height: 1120),
        needsFocus: false,
        view: { _ in AnyView(ActivityRuleGallery()) }
    )
}
