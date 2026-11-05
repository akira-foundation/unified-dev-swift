import SwiftUI
import Core

struct CanvasCommentMarks: View {
    let comments: CanvasCommentControls
    let viewport: CanvasViewport
    @Binding var composingAt: CanvasPoint?
    let placed: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(comments.marks) { comment in
                let origin = viewport.toScreen(comment.anchor)
                CanvasCommentMark(comment: comment, comments: comments)
                    .frame(width: 0, height: 0, alignment: .topLeading)
                    .position(x: origin.x - CanvasCommentMark.diameter / 2, y: origin.y - CanvasCommentMark.diameter / 2)
            }
            if let composingAt {
                let origin = viewport.toScreen(composingAt)
                Color.clear
                    .frame(width: 1, height: 1)
                    .popover(isPresented: composerShown, arrowEdge: .trailing) {
                        CanvasCommentComposer(
                            action: "Comment",
                            commit: { text in
                                comments.add(composingAt, text)
                                self.composingAt = nil
                                placed()
                            },
                            cancel: { self.composingAt = nil }
                        )
                        .padding(12)
                        .frame(width: 280)
                    }
                    .position(x: origin.x, y: origin.y)
            }
        }
    }

    private var composerShown: Binding<Bool> {
        Binding(get: { composingAt != nil }, set: { if !$0 { composingAt = nil } })
    }
}

struct CanvasCommentMark: View {
    static let diameter = 26.0

    let comment: CanvasComment
    let comments: CanvasCommentControls

    @State private var isOpen = false

    private var status: CanvasCommentStatus { comments.status(comment) }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Button { isOpen = true } label: {
                Image(systemName: symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: Self.diameter, height: Self.diameter)
                    .background(tint, in: Circle())
                    .overlay { Circle().stroke(.white, lineWidth: 1.5) }
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            }
            .buttonStyle(.plain)
            .help(status.detail)
            .accessibilityLabel("Comment: \(comment.text). \(status.title). \(status.detail)")
            .popover(isPresented: $isOpen, arrowEdge: .trailing) {
                CanvasCommentRow(comment: comment, comments: comments)
                    .padding(12)
                    .frame(width: 300)
            }
            label
        }
        .fixedSize()
    }

    @ViewBuilder
    private var label: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: status.title).font(.caption.weight(.semibold))
            if comment.state != .working {
                Text(verbatim: status.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 190, alignment: .leading)
            }
            if CanvasCommentBoard.canResend(comment) {
                Button("Resend") { comments.resend(comment.id) }
                    .controlSize(.small)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
    }

    private var symbol: String { comment.state == .working ? "ellipsis" : status.needsOwner ? "exclamationmark" : "clock" }

    private var tint: Color {
        if comment.state == .unanswered { return .red }
        return status.needsOwner ? .orange : .accentColor
    }
}
