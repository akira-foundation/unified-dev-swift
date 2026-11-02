import SwiftUI
import Core

struct CodeBlockRunStatus: View {
    var run: CodeBlockRun
    @State private var showsOutput = false

    private static let outputHeight: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            HStack(spacing: Metrics.spacing) {
                mark
                Text(run.summary)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: MarkdownMetrics.blockGap)
                if run.output != nil {
                    Button(showsOutput ? "Hide output" : "Show output") { showsOutput.toggle() }
                        .linkButton()
                        .font(Typo.caption)
                }
            }
            if showsOutput, let output = run.output {
                if run.outputScrolls {
                    ScrollView([.vertical, .horizontal]) { outputText(output) }
                        .frame(height: Self.outputHeight)
                } else {
                    ScrollView(.horizontal) { outputText(output) }
                }
            }
        }
        .padding(.horizontal, MarkdownMetrics.blockGap)
        .padding(.vertical, Metrics.spacing)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.border).frame(height: Metrics.outline)
        }
    }

    private func outputText(_ output: String) -> some View {
        Text(output)
            .font(Typo.code)
            .foregroundStyle(Palette.textPrimary)
            .textSelection(.enabled)
    }

    @ViewBuilder
    private var mark: some View {
        switch run.mark {
        case .progress:
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.mini)
        case .succeeded:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.positive)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.negative)
        case .stopped:
            Image(systemName: "stop.circle").foregroundStyle(Palette.textTertiary)
        }
    }
}
