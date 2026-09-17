import SwiftUI
import Core

struct WorktreeSetupStrip: View {
    var readiness: WorktreeReadiness

    var body: some View {
        if let sentence = readiness.sentence {
            HStack(spacing: Metrics.spacing) {
                if readiness == .installing {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                        .frame(width: Metrics.glyph, height: Metrics.glyph)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .imageScale(.small)
                        .foregroundStyle(Palette.warning)
                        .frame(width: Metrics.glyph, height: Metrics.glyph)
                }

                Text(sentence)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.vertical, Metrics.spacing)
            .frame(maxWidth: .infinity)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
