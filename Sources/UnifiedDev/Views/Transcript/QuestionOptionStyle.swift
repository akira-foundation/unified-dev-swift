import SwiftUI

struct QuestionOptionStyle: ButtonStyle {
    var isChosen: Bool
    var isLive: Bool
    var forcesHover: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        Plate(
            configuration: configuration,
            isChosen: isChosen,
            isLive: isLive,
            forcesHover: forcesHover
        )
    }

    private struct Plate: View {
        let configuration: Configuration
        var isChosen: Bool
        var isLive: Bool

        @State private var isHovered: Bool
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        init(configuration: Configuration, isChosen: Bool, isLive: Bool, forcesHover: Bool) {
            self.configuration = configuration
            self.isChosen = isChosen
            self.isLive = isLive
            _isHovered = State(initialValue: forcesHover)
        }

        var body: some View {
            configuration.label
                .padding(.vertical, Metrics.spacing)
                .padding(.horizontal, Metrics.spacingWide)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
                        .fill(fill)
                )
                .contentShape(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
                .animation(reduceMotion ? nil : Motion.hover, value: isHovered)
                .onHover { isHovered = $0 }
        }

        private var fill: Color {
            if isChosen || (isLive && configuration.isPressed) { return Palette.selected }
            if isLive, isHovered { return Palette.hover }
            return .clear
        }
    }
}
