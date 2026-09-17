import SwiftUI
import Core

struct RetryRowView: View {
    var run: RetryRun
    var isStill = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var retry: AgentRetry { run.latest }

    private var tint: Color {
        run.patience == .settling ? Palette.textTertiary : Palette.warning
    }

    private var isRaised: Bool { run.patience != .settling }

    private var sentence: String {
        [retry.note, retry.waitPhrase].compactMap { $0 }.joined(separator: " ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TranscriptLayout.tight) {
            header
            Text(sentence)
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: TranscriptLayout.proseMeasure, alignment: .leading)
                .padding(.leading, TranscriptLayout.glyphWidth + TranscriptLayout.glyphGap)

            drain
                .padding(.top, TranscriptLayout.tight)
                .padding(.leading, TranscriptLayout.glyphWidth + TranscriptLayout.glyphGap)
        }
        .padding(isRaised ? TranscriptLayout.tight : 0)
        .background {
            if isRaised {
                RoundedRectangle(cornerRadius: Metrics.corner)
                    .fill(Palette.cautionWash)
                    .overlay {
                        RoundedRectangle(cornerRadius: Metrics.corner)
                            .strokeBorder(Palette.cautionBorder, lineWidth: Metrics.outline)
                    }
            }
        }
        .padding(.horizontal, TranscriptLayout.inset)
        .padding(.vertical, TranscriptLayout.inset)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(retry.headline). \(sentence)")
    }

    private var header: some View {
        HStack(spacing: TranscriptLayout.glyphGap) {
            BreathingMark(isMoving: !isStill && !reduceMotion) {
                TranscriptGlyph(symbol: "arrow.trianglehead.clockwise", tint: tint)
            }

            Text(retry.headline)
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)

            Spacer(minLength: TranscriptLayout.tight)

            Text("\(retry.attempt) of \(retry.maxAttempts)")
                .font(Typo.caption)
                .monospacedDigit()
                .foregroundStyle(tint)
                .fixedSize()
        }
    }

    @ViewBuilder
    private var drain: some View {
        Group {
            if isStill || reduceMotion {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(tint.opacity(0.12))
                        Capsule().fill(tint.opacity(0.6))
                            .frame(width: proxy.size.width * 0.62)
                    }
                }
            } else {
                NoticeDrainBar(
                    fraction: 1,
                    remaining: .seconds(retry.delay),
                    generation: retry.attempt,
                    tint: tint
                )
            }
        }
        .frame(height: Metrics.hairline * 2)
        .frame(maxWidth: TranscriptLayout.proseMeasure, alignment: .leading)
    }
}
