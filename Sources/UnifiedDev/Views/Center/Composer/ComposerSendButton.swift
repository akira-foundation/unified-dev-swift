import SwiftUI

struct ComposerSendButton: View {
    var intent: ComposerIntent = .send
    var queues: Bool = false
    var canSend: Bool
    var onSend: @MainActor () -> Void

    static let glyph = Metrics.rowHeight - Metrics.spacingSmall * 3

    private var isNamed: Bool { intent != .send }

    var body: some View {
        Button(action: onSend) {
            if isNamed {
                HStack(spacing: Metrics.spacingSmall) {
                    Text(intent.title)
                    Image(systemName: "return")
                        .imageScale(.small)
                }
                .font(Typo.labelEmphasis)
                .padding(.horizontal, Metrics.spacing)
                .frame(height: Self.glyph)
            } else {
                Label(intent.title, systemImage: "arrow.up")
                    .labelStyle(.iconOnly)
                    .font(Typo.labelEmphasis)
                    .padding(Metrics.spacing)
            }
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(isNamed ? .capsule : .circle)
        .contentShape(Rectangle())
        .tint(Palette.accentFill)
        .disabled(!canSend)
        .help(queues ? "Queue this message. It goes when the queue moves (Return)" : intent.help)
    }
}
