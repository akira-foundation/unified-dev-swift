import SwiftUI
import Core

struct ProseLeadingGallery: View {
    private static let sample = """
    Ran the suite and the failure is real. `DiffParser.parse(hunk:)` drops the last line of a \
    hunk whose header has no trailing count, which is every single-line hunk `git` writes.
    """

    private static let wasFixed: CGFloat = 3

    private static let command =
        "rm -rf node_modules && npm ci --prefer-offline && npm run build -- --mode production"

    private static let paneWidth: CGFloat = 340

    private let face = ChatFont.standard

    var body: some View {
        HStack(alignment: .top, spacing: 32) {
            column("Prose, three fixed points") { size in
                prose(leading: Self.wasFixed)
                    .environment(\.fontScale, size.scale)
            }
            column("Prose, \(ChatLineHeight.defaultChoice.ratio) of the size") { size in
                prose()
                    .environment(\.fontScale, size.scale)
            }
            column("Command, 1.3 of its line box") { size in
                commandBlock()
                    .environment(\.fontScale, size.scale)
            }
            lineHeightColumn()
        }
        .environment(\.chatFont, face)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func column<Each: View>(
        _ title: String, @ViewBuilder each: @escaping (ChatTextSize) -> Each
    ) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)

            ForEach(ChatTextSize.allCases) { size in
                VStack(alignment: .leading, spacing: 6) {
                    Text(caption(for: size))
                        .font(Typo.micro)
                        .foregroundStyle(Palette.textTertiary)
                    each(size)
                }
            }
        }
        .frame(width: Self.paneWidth, alignment: .leading)
    }

    private func lineHeightColumn() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Prose, the five line-height steps")
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)

            ForEach(ChatLineHeight.allCases) { step in
                VStack(alignment: .leading, spacing: 6) {
                    Text(caption(for: step))
                        .font(Typo.micro)
                        .foregroundStyle(Palette.textTertiary)
                    prose()
                        .environment(\.fontScale, ChatTextSize.defaultChoice.scale)
                        .environment(\.chatLineHeight, step)
                }
            }
        }
        .frame(width: Self.paneWidth, alignment: .leading)
    }

    private func caption(for size: ChatTextSize) -> String {
        let leading = TranscriptLayout.proseLeading(
            Typo.body, scale: size.scale, face: face, lineHeight: .defaultChoice
        )
        return "\(size.title), prose +\(Int(leading))pt"
    }

    private func caption(for step: ChatLineHeight) -> String {
        let leading = TranscriptLayout.proseLeading(
            Typo.body, scale: ChatTextSize.defaultChoice.scale, face: face, lineHeight: step
        )
        return "\(step.title), \(step.ratio) of the size, prose +\(Int(leading))pt"
    }

    @ViewBuilder
    private func prose(leading: CGFloat? = nil) -> some View {
        let block = MarkdownView(Self.sample)
            .font(Typo.body)
            .frame(maxWidth: .infinity, alignment: .leading)

        if let leading {
            block.lineSpacing(leading)
        } else {
            block.proseLeading()
        }
    }

    private func commandBlock() -> some View {
        CommandSample(text: Self.command)
    }
}

private struct CommandSample: View {
    let text: String

    @Environment(\.fontScale) private var fontScale
    @Environment(\.chatFont) private var chatFont

    var body: some View {
        Text(text)
            .font(Typo.codeSmall)
            .foregroundStyle(Palette.textPrimary)
            .lineSpacing(TranscriptLayout.codeLeading(
                Typo.codeSmall, scale: fontScale, face: chatFont
            ))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.spacingWide)
            .padding(.vertical, Metrics.spacing)
            .background(
                RoundedRectangle(cornerRadius: Metrics.cornerSmall, style: .continuous)
                    .fill(Palette.surfaceSunken)
            )
    }
}

extension Gallery {
    static let proseLeading = Gallery(
        name: "prose-leading",
        title: "Line height across the chat text sizes and the line-height steps",
        size: CGSize(width: 1_560, height: 1_320),
        needsFocus: false,
        view: { _ in AnyView(ProseLeadingGallery()) }
    )
}
