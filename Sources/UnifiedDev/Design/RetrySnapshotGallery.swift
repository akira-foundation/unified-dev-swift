import SwiftUI
import Core

struct RetrySnapshotGallery: View {
    private static func retry(_ attempt: Int, _ delay: TimeInterval, status: Int = 529) -> AgentRetry {
        AgentRetry(attempt: attempt, maxAttempts: 10, delay: delay, status: status)
    }

    private static func run(_ attempt: Int, _ delay: TimeInterval, status: Int = 529) -> RetryRun {
        RetryRun(retry(attempt, delay, status: status))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
                group("What it used to say, for three minutes and fourteen seconds") {
                    StreamingStatusView(glyph: nil, text: "Requesting")
                }

                group("Attempt 1 of 10, six hundred milliseconds in. Not news yet.") {
                    RetryRowView(run: Self.run(1, 0.6), isStill: true)
                }

                group("Attempt 5 of 10. It lifts onto a plate: a different object, not a longer sentence.") {
                    RetryRowView(run: Self.run(5, 8.757), isStill: true)
                }

                group("Attempt 9 of 10, two and a half minutes in.") {
                    RetryRowView(run: Self.run(9, 37.186), isStill: true)
                }

                group("A 429 rather than a 529. Same shape, different diagnosis.") {
                    RetryRowView(run: Self.run(6, 19.5, status: 429), isStill: true)
                }

                group("Nothing came back at all, which may be this machine.") {
                    RetryRowView(
                        run: RetryRun(AgentRetry(
                            attempt: 4, maxAttempts: 10, delay: 12, status: nil, category: "timeout"
                        )),
                        isStill: true
                    )
                }

                group("And what is left under the turn once it got through.") {
                    Text(recovered.recoveredSentence)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textTertiary)
                        .padding(.horizontal, TranscriptLayout.inset)
                }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.windowBackground)
    }

    private var recovered: RetryRun {
        var run = Self.run(1, 0.6)
        run.absorb(Self.retry(4, 4.7))
        return run
    }

    @ViewBuilder
    private func group(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
            content()
        }
    }
}

extension Gallery {
    static let retries = Gallery(
        name: "retries",
        title: "Retries",
        size: CGSize(width: 860, height: 1_020),
        needsFocus: false,
        view: { _ in AnyView(RetrySnapshotGallery()) }
    )
}
