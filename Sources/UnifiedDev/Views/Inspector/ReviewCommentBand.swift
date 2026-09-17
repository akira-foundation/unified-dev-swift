import SwiftUI
import Core

struct ReviewCommentBandView: View {
    var placement: ReviewPlacement
    var width: CGFloat
    var editing: Binding<String>?
    var onBeginEdit: @MainActor () -> Void
    var onCommitEdit: @MainActor () -> Void
    var onCancelEdit: @MainActor () -> Void
    var onRemove: @MainActor () -> Void

    @State private var isHovered: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        placement: ReviewPlacement,
        width: CGFloat,
        editing: Binding<String>? = nil,
        isHovered: Bool = false,
        onBeginEdit: @escaping @MainActor () -> Void,
        onCommitEdit: @escaping @MainActor () -> Void,
        onCancelEdit: @escaping @MainActor () -> Void,
        onRemove: @escaping @MainActor () -> Void
    ) {
        self.placement = placement
        self.width = width
        self.editing = editing
        self.onBeginEdit = onBeginEdit
        self.onCommitEdit = onCommitEdit
        self.onCancelEdit = onCancelEdit
        self.onRemove = onRemove
        _isHovered = State(initialValue: isHovered)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.spacing) {
            Image(systemName: "text.bubble")
                .font(Typo.micro)
                .imageScale(.small)
                .foregroundStyle(Palette.textSecondary)

            VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                if let note {
                    Text(note)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .italic()
                }

                if let editing {
                    ReviewCommentField(
                        text: editing,
                        placeholder: "Say what this line should be",
                        onSubmit: onCommitEdit,
                        onCancel: onCancelEdit
                    )
                    ReviewCommentEditorButtons(
                        confirmTitle: "Save",
                        canConfirm: ReviewCommentEdit.canSubmit(editing.wrappedValue),
                        confirmHelp: "Save the comment (Return)",
                        onConfirm: onCommitEdit,
                        onCancel: onCancelEdit
                    )
                } else {
                    Text(placement.comment.body)
                        .font(Typo.body)
                        .foregroundStyle(Palette.textPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: 560, alignment: .leading)

            if editing == nil {
                HStack(spacing: Metrics.spacingSmall) {
                    control(
                        "pencil",
                        help: "Edit this comment",
                        label: "Edit the comment on \(chip)",
                        action: onBeginEdit
                    )
                    control(
                        "xmark",
                        help: "Remove this comment",
                        label: "Remove the comment on \(chip)",
                        action: onRemove
                    )
                }
                .animation(reduceMotion ? nil : Motion.hover, value: isHovered)
            }
        }
        .padding(.horizontal, Metrics.inset)
        .padding(.vertical, Metrics.spacingWide)
        .frame(width: width, alignment: .leading)
        .background(Palette.reviewBand)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Review comment, \(chip)")
    }

    private func control(
        _ symbol: String,
        help: String,
        label: String,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(Typo.micro)
                .imageScale(.small)
                .foregroundStyle(isHovered ? Palette.textPrimary : Palette.textSecondary)
                .frame(width: 18, height: 18)
                .background(
                    RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                        .fill(Palette.hover)
                        .opacity(isHovered ? 1 : 0)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(label)
    }

    private var chip: String {
        ReviewCommentSummary.chip(for: placement.comment)
    }

    private var note: String? {
        let anchor = placement.comment.anchor
        let subject = anchor.isRange ? "These lines" : "This line"
        switch placement.status {
        case .placed(_, moved: false):
            return nil
        case .placed(let spot, moved: true):
            guard anchor.isRange else {
                return "Moved here from line \(anchor.line); now line \(spot.line)."
            }
            return "Moved here from lines \(anchor.line) to \(anchor.lastLine); "
                + "now lines \(spot.line) to \(spot.line + anchor.span - 1)."
        case .hidden(let line):
            guard anchor.isRange else {
                return "\(chip): the line is now line \(line), which this diff does not show."
            }
            return "\(chip): these lines are now \(line) to \(line + anchor.span - 1), "
                + "which this diff does not show."
        case .outdated:
            return "\(chip): \(subject.lowercased()) \(anchor.isRange ? "have" : "has") changed "
                + "or \(anchor.isRange ? "are" : "is") gone. "
                + "The comment will be sent with the code as it looked when it was written."
        }
    }
}

struct ReviewCommentEditorView: View {
    @Binding var text: String
    var width: CGFloat
    var onCommit: @MainActor () -> Void
    var onCancel: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            ReviewCommentField(
                text: $text,
                placeholder: "Leave a comment",
                onSubmit: onCommit,
                onCancel: onCancel
            )

            ReviewCommentEditorButtons(
                confirmTitle: "Comment",
                canConfirm: ReviewCommentEdit.canSubmit(text),
                confirmHelp: "Add the comment (Return)",
                onConfirm: onCommit,
                onCancel: onCancel
            )
        }
        .frame(maxWidth: 560, alignment: .leading)
        .padding(.horizontal, Metrics.inset)
        .padding(.vertical, Metrics.spacingWide)
        .frame(width: width, alignment: .leading)
        .background(Palette.reviewBand)
    }
}

struct ReviewCommentEditorButtons: View {
    var confirmTitle: String
    var canConfirm: Bool
    var confirmHelp: String
    var onConfirm: @MainActor () -> Void
    var onCancel: @MainActor () -> Void

    var body: some View {
        HStack(spacing: Metrics.spacing) {
            Spacer(minLength: 0)

            Button("Cancel", action: onCancel)
                .buttonStyle(.plain)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, Metrics.spacingWide)
                .padding(.vertical, Metrics.spacingSmall)
                .background(Palette.hover, in: RoundedRectangle(cornerRadius: Metrics.cornerSmall))

            Button(action: onConfirm) {
                HStack(spacing: Metrics.spacingSmall) {
                    Text(confirmTitle)
                    Image(systemName: "return")
                        .imageScale(.small)
                }
                .font(Typo.captionEmphasis)
                .foregroundStyle(Palette.selectedEmphasizedText)
                .padding(.horizontal, Metrics.spacingWide)
                .padding(.vertical, Metrics.spacingSmall)
                .background(
                    Palette.controlAccent.opacity(canConfirm ? 1 : 0.4),
                    in: RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                )
            }
            .buttonStyle(.plain)
            .disabled(!canConfirm)
            .help(confirmHelp)
        }
        .frame(maxWidth: 560)
    }
}
