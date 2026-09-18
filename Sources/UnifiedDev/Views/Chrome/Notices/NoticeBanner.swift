import SwiftUI
import Core

struct NoticeBanner: View {
    let notice: Notice
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.fontScale) private var fontScale

    @State private var remaining: Duration?
    @State private var fraction: Double = 1
    @State private var generation = 0
    @State private var isHeld = false
    @State private var deadline: ContinuousClock.Instant?

    private var lifetime: Duration? { notice.lifetime }

    private static let cardWidth: CGFloat = 400
    private static let drainHeight: CGFloat = 2

    var body: some View {
        NoticePiece(tone: notice.tone, announcement: notice.spoken, onDismiss: onDismiss) {
            sentences
        }
        .overlay(alignment: .bottom) { drain }
        .frame(maxWidth: Self.cardWidth, alignment: .leading)
        .noticeGlass(notice.tone)
        .padding(Metrics.gutter)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(notice.spoken)
        .onHover { isHeld = $0 }
        .onChange(of: isHeld) { _, held in held ? hold() : release() }
        .task(id: generation) { await countdown() }
        .onChange(of: notice.id, initial: true) { _, _ in restart() }
        .acceptsCaptureNoticeHold { isHeld = $0 }
    }

    private var sentences: some View {
        let text = notice.text
        return VStack(alignment: .leading, spacing: Metrics.spacingHair) {
            run(text.fact, rung: Typo.labelEmphasis)
                .foregroundStyle(Palette.textPrimary)

            if !text.reason.isEmpty {
                run(text.reason, rung: Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .textSelection(.enabled)
    }

    private func run(_ runs: [NoticeRun], rung: ScaledFont) -> Text {
        var sentence = AttributedString()
        for piece in runs {
            var part = AttributedString(piece.text)
            part.font = piece.isMachine
                ? rung.monospacedCompanion(scale: fontScale)
                : rung.resolved(scale: fontScale)
            sentence += part
        }
        return Text(sentence)
    }

    @ViewBuilder
    private var drain: some View {
        if lifetime != nil, !reduceMotion {
            NoticeDrainBar(
                fraction: fraction,
                remaining: isHeld ? nil : remaining,
                generation: generation,
                tint: notice.tone.colour
            )
            .frame(height: Self.drainHeight)
                .accessibilityHidden(true)
        }
    }

    private func restart() {
        remaining = lifetime
        fraction = 1
        generation += 1
    }

    private func hold() {
        guard let lifetime, let remaining else { return }
        let started = ContinuousClock.now
        let left = deadline.map { max(.zero, started.duration(to: $0)) } ?? remaining
        self.remaining = left
        fraction = lifetime > .zero ? left.seconds / lifetime.seconds : 0
        generation += 1
    }

    private func release() {
        guard remaining != nil else { return }
        generation += 1
    }

    private func countdown() async {
        guard !isHeld, let remaining, remaining > .zero else {
            deadline = nil
            return
        }
        deadline = .now + remaining
        try? await Task.sleep(for: remaining)
        guard !Task.isCancelled else { return }
        onDismiss()
    }
}
