import SwiftUI

struct ComposerSendButton: View {
    var intent: ComposerIntent = .send
    var queues: Bool = false
    var canSend: Bool
    var onSend: @MainActor () -> Void

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
                .padding(.horizontal, Metrics.spacingSmall)
            } else {
                Label(intent.title, systemImage: "arrow.up")
                    .labelStyle(.iconOnly)
                    .font(Typo.labelEmphasis)
                    .padding(Metrics.spacing)
            }
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(isNamed ? .capsule : .circle)
        .contentShape(Rectangle())
        .tint(Palette.accentFill)
        .disabled(!canSend)
        .help(queues ? "Queue this message. It goes when the queue moves (Return)" : intent.help)
    }
}
