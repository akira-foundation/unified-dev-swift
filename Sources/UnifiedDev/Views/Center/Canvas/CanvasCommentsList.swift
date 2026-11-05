import SwiftUI
import Core

struct CanvasCommentsList: View {
    let comments: CanvasCommentControls
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Comments").font(.headline)
                Spacer()
                Button(action: close) { Image(systemName: "xmark") }
                    .buttonStyle(.borderless)
                    .help("Close")
                    .accessibilityLabel("Close")
            }
            .padding(12)
            Divider()
            if comments.listed.isEmpty {
                ContentUnavailableView(
                    "No comments",
                    systemImage: CanvasTool.comment.symbol,
                    description: Text("Use the comment button, then click a slide.")
                )
                .frame(maxHeight: .infinity)
            } else {
                List(comments.listed) { comment in
                    CanvasCommentRow(comment: comment, comments: comments)
                        .padding(.vertical, 4)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .onAppear(perform: comments.markListRead)
        .onChange(of: comments.unreadDeclined) { comments.markListRead() }
    }
}

struct CanvasCommentRow: View {
    let comment: CanvasComment
    let comments: CanvasCommentControls

    @State private var isEditing = false

    private var status: CanvasCommentStatus { comments.status(comment) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: status.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(status.needsOwner ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
            if isEditing {
                CanvasCommentComposer(
                    action: "Save",
                    initial: comment.text,
                    commit: { text in
                        comments.edit(comment.id, text)
                        isEditing = false
                    },
                    cancel: { isEditing = false }
                )
            } else {
                Text(verbatim: comment.text).textSelection(.enabled)
                if let label = CanvasCommentBoard.responseLabel(of: comment), let response = comment.response {
                    Text(verbatim: label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(verbatim: response).font(.callout).textSelection(.enabled)
                } else {
                    Text(verbatim: status.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                actions
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: 8) {
            if CanvasCommentBoard.canResend(comment) {
                Button("Resend") { comments.resend(comment.id) }
            }
            if CanvasCommentBoard.canEdit(comment) {
                Button("Edit") { isEditing = true }
            }
            if CanvasCommentBoard.canDelete(comment) {
                Button("Delete", role: .destructive) { comments.delete(comment.id) }
            }
        }
        .controlSize(.small)
    }
}
