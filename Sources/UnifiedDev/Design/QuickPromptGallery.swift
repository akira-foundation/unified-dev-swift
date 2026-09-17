import SwiftUI
import Core

struct QuickPromptGallery: View {
    var app: AppModel

    private var prompts: [QuickPrompt] {
        [
            QuickPrompt(
                name: "Explain changes",
                symbol: "doc.richtext",
                text: "Explain the changes made in this PR as HTML. Open it as a new tab in this workspace.",
                sortOrder: 0
            ),
            QuickPrompt(
                name: "Run the tests and fix whatever comes back failing",
                symbol: "checkmark.seal",
                text: "Run make test. If anything fails, fix it and run the failing test again on its own.",
                sendsImmediately: true,
                sortOrder: 1
            ),
            QuickPrompt(
                name: "Hunt the flake",
                symbol: "\u{1F41B}",
                text: "Run the failing test twenty times and say what makes it fail.",
                sortOrder: 2
            ),
            QuickPrompt(
                name: "",
                symbol: "text.alignleft",
                text: "Walk me through the diff, file by file, and say why each change is there.",
                opensNewChat: true,
                sortOrder: 3
            ),
            QuickPrompt(
                name: "Ship it",
                symbol: "\u{1F680}",
                text: "Push the branch, open the pull request, and wait for the checks.",
                sendsImmediately: true,
                opensNewChat: true,
                sortOrder: 4
            ),
            QuickPrompt(
                name: "Open a pull request against the release branch and write the description "
                    + "from the commits rather than from the diff",
                symbol: "arrow.triangle.pull",
                text: "Push the branch and open a pull request. Three sentences, no headings.",
                sortOrder: 5
            ),
            QuickPrompt(
                name: "Regenerate\u{200B}TheSnapshotFixturesForEveryGalleryPageInOneGo",
                symbol: "camera",
                text: "Run every gallery capture and replace the fixtures under Tests.",
                sortOrder: 6
            ),
        ]
    }

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.pane) {
            VStack(alignment: .leading, spacing: Metrics.pane) {
                panel("The first row, highlighted on opening", selected: 0)
                panel("Nothing written yet", selected: nil, empty: true)
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: Metrics.pane) {
                form("At rest, a symbol chosen", prompt: prompts[0])
                form("A name longer than the row it is typed in", prompt: prompts[5])
                captioned("What Delete asks first") { deleteQuestion }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: Metrics.pane) {
                form("The picker, open on Icons and scrolled to the mark",
                     prompt: prompts[6], picking: true)
                form("The picker, open on Emojis", prompt: prompts[4], picking: true)
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: Metrics.pane) {
                form("Both switches on: one press opens a chat and runs", prompt: prompts[4])
                form("A chat, and the words left waiting in it", prompt: prompts[3])
                Spacer(minLength: 0)
            }
        }
        .padding(Metrics.pane)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.surface)
        .environment(app)
    }

    private var deleteQuestion: some View {
        ConfirmationSheet(
            confirmation: QuickPromptDeletion.confirmation(for: prompts[5]),
            onConfirm: {},
            onCancel: {}
        )
        .fixedSize()
    }

    private func form(
        _ caption: String, prompt: QuickPrompt, picking: Bool = false
    ) -> some View {
        captioned(caption) {
            QuickPromptFormPreview(
                prompt: prompt,
                startsPickingMark: picking,
            )
            .frame(width: 380)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.corner + 2))
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.corner + 2)
                    .strokeBorder(Palette.border, lineWidth: Metrics.hairline)
            }
        }
    }

    private struct QuickPromptFormPreview: View {
        @State private var draft: QuickPromptFormDraft
        var startsPickingMark: Bool

        init(prompt: QuickPrompt, startsPickingMark: Bool) {
            _draft = State(initialValue: QuickPromptFormDraft(editing: prompt))
            self.startsPickingMark = startsPickingMark
        }

        var body: some View {
            QuickPromptForm(
                draft: $draft,
                startsPickingMark: startsPickingMark,
                onCancel: {}, onSave: { _ in }, onDelete: {}
            )
        }
    }

    private func panel(
        _ caption: String, selected: Int?, empty: Bool = false, emphasized: Bool = true
    ) -> some View {
        captioned(caption) {
            VStack(alignment: .leading, spacing: 0) {
                searchLine
                Hairline()

                if empty {
                    VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                        Text("Nothing here yet.")
                            .font(Typo.body)
                            .foregroundStyle(Palette.textSecondary)
                        Text("A quick prompt is a few lines you find yourself typing again.")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, contentInset)
                    .padding(.vertical, Metrics.gutter)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(prompts.enumerated()), id: \.offset) { index, prompt in
                            QuickPromptRow(
                                row: .personal(prompt),
                                isSelected: index == selected,
                                onPick: {}, onHover: {}, onEdit: {}, onDelete: {}
                            )
                        }
                    }
                    .padding(.horizontal, listInset)
                    .padding(.vertical, Metrics.spacingSmall)
                    .environment(\.controlActiveState, emphasized ? .key : .inactive)
                }

                Hairline()
                newLine
            }
            .frame(width: 380)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.corner + 2))
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.corner + 2)
                    .strokeBorder(Palette.border, lineWidth: Metrics.hairline)
            }
        }
    }

    private func captioned(_ caption: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacingWide) {
            Text(caption)
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
            content()
        }
    }

    private var listInset: CGFloat { Metrics.spacingWide }
    private var contentInset: CGFloat { Metrics.spacingWide + Metrics.spacing }

    private var searchLine: some View {
        HStack(spacing: Metrics.spacing) {
            Image(systemName: "magnifyingglass")
                .imageScale(.small)
                .foregroundStyle(Palette.textTertiary)
                .frame(width: Metrics.repoIcon)
            Text("Search quick prompts")
                .font(Typo.body)
                .foregroundStyle(Palette.textTertiary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, contentInset)
        .padding(.vertical, Metrics.spacingSmall)
        .frame(height: Metrics.rowHeight + Metrics.spacingWide)
    }

    private var newLine: some View {
        HStack(spacing: Metrics.spacing) {
            Image(systemName: "plus")
                .imageScale(.medium)
                .foregroundStyle(Palette.textSecondary)
                .frame(width: Metrics.repoIcon, height: Metrics.repoIcon)
            Text("New quick prompt")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.spacing)
        .frame(height: Metrics.rowHeight)
        .padding(.horizontal, listInset)
        .padding(.vertical, Metrics.spacingSmall)
    }
}

extension Gallery {
    static let quickPrompts = Gallery(
        name: "quick-prompts",
        title: "Quick prompts",
        size: CGSize(width: 1720, height: 1600),
        needsFocus: false,
        view: { app in AnyView(QuickPromptGallery(app: app)) }
    )
}
