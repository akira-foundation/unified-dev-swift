import SwiftUI

struct PullRequestNotice: Identifiable, Equatable {
    let id = UUID()
    var tone: InspectorNotice.Tone
    var title: String
    var message: String
    var details: String?
}

struct InspectorNotice: View {
    enum Tone {
        case info
        case failure

        var color: Color {
            switch self {
            case .info: Palette.accent
            case .failure: Palette.negative
            }
        }

        var glyph: String {
            switch self {
            case .info: "info.circle.fill"
            case .failure: "exclamationmark.triangle.fill"
            }
        }
    }

    let notice: PullRequestNotice
    let onDismiss: () -> Void

    @State private var isShowingDetails = false

    private var tone: Tone { notice.tone }
    private var title: String { notice.title }
    private var message: String { notice.message }
    private var details: String? { notice.details }

    var body: some View {
        HStack(alignment: .top, spacing: InspectorLayout.gap) {
            Image(systemName: tone.glyph)
                .font(Typo.caption)
                .foregroundStyle(tone.color)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: InspectorLayout.tight) {
                Text(title)
                    .font(Typo.captionEmphasis)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .font(Typo.micro)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                if details != nil {
                    Button(isShowingDetails ? "Hide details" : "Show details") {
                        isShowingDetails.toggle()
                    }
                    .linkButton()
                    .font(Typo.micro)
                }

                if isShowingDetails, let details {
                    ScrollView(.horizontal) {
                        Text(details)
                            .font(Typo.codeTiny)
                            .foregroundStyle(Palette.textTertiary)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 96)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Dismiss", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .controlSize(.small)
                .foregroundStyle(Palette.textTertiary)
                .help("Dismiss")
        }
        .padding(.horizontal, InspectorLayout.inset)
        .padding(.vertical, Metrics.spacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.color.opacity(InspectorLayout.tintOpacity))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title). \(message)")
    }
}
