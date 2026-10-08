import SwiftUI
import Core

enum FeedbackPhase: Equatable {
    case idle
    case sending
    case sent
    case failed(String)

    var isSending: Bool { self == .sending }
}

struct FeedbackHeader: View {
    var title: String
    var blurb: String

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingWide) {
            Text(title)
                .font(Typo.heading)
                .foregroundStyle(Palette.textPrimary)

            Text(blurb)
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct FeedbackStatus: View {
    var phase: FeedbackPhase

    var body: some View {
        if case .failed(let message) = phase {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(Typo.label)
                .foregroundStyle(Palette.warning)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct FeedbackSentCard: View {
    var title: String
    var detail: String
    var link: URL?
    var onDismiss: @MainActor () -> Void

    private static let width: CGFloat = 380

    var body: some View {
        VStack(spacing: Metrics.gutter) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Palette.controlAccent)

            VStack(spacing: Metrics.spacingWide) {
                Text(title)
                    .font(Typo.heading)
                    .foregroundStyle(Palette.textPrimary)

                Text(detail)
                    .font(Typo.label)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let link {
                Link(Feedback.Copy.sentOpenIssue, destination: link)
                    .font(Typo.label)
                    .foregroundStyle(Palette.link)
                    .underline()
            }

            Button(Feedback.Copy.sentDismiss, action: onDismiss)
                .buttonStyle(.borderedProminent)
                .tint(Palette.controlAccent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(Metrics.pane)
        .frame(width: Self.width)
        .background(Palette.surface)
        .onExitCommand(perform: onDismiss)
    }
}

struct FeedbackSendButton: View {
    var title: String
    var isEnabled: Bool
    var isSending: Bool
    var action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Metrics.spacingSmall) {
                Text(title)

                if isSending {
                    ProgressView()
                        .controlSize(.mini)
                        .frame(width: 20)
                } else {
                    Text(verbatim: "⌘↩").opacity(0.65)
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(Palette.controlAccent)
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(!isEnabled)
    }
}

struct FeedbackEnvironmentNote: View {
    var body: some View {
        Text(Feedback.Copy.environmentNote)
            .font(Typo.micro)
            .foregroundStyle(Palette.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
