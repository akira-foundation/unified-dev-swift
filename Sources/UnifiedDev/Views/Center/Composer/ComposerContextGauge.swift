import SwiftUI

struct ComposerContextGauge: View {
    var reading: ContextWindowUsage.Reading
    @Binding var isShowingDetail: Bool

    var body: some View {
        Button {
            isShowingDetail = true
        } label: {
            Text(reading.percent)
                .monospacedDigit()
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, Metrics.spacing)
                .padding(.vertical, Metrics.spacingSmall)
                .contentShape(Rectangle())
        }
        .help("Context window")
        .accessibilityLabel("Context window")
        .accessibilityValue(reading.spoken)
    }
}

struct ContextWindowBar: View {
    var fraction: Double
    var isCrowded: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.selected)
                Capsule()
                    .fill(isCrowded ? Palette.warning : Palette.accent(beside: [.warning]))
                    .frame(width: max(proxy.size.height, proxy.size.width * fraction))
            }
        }
        .accessibilityHidden(true)
    }
}
