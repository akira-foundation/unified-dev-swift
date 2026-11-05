import SwiftUI
import Core

struct CanvasCommentMarks: View {
    let comments: CanvasCommentControls
    let viewport: CanvasViewport
    @Binding var composingAt: CanvasPoint?
    let placed: () -> Void

    @State private var typed = ""

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
                            text: $typed,
                            commit: { text in
                                comments.add(composingAt, text)
                                typed = ""
                                self.composingAt = nil
                                placed()
                            },
                            cancel: {
                                typed = ""
                                self.composingAt = nil
                            }
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
    static let quotedLines = 5

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
                CanvasCommentPopover(comment: comment, comments: comments)
            }
            label
        }
        .fixedSize()
    }

    @ViewBuilder
    private var label: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: status.title).font(.caption.weight(.semibold))
            if comments.canSend(comment) {
                Text(verbatim: comment.text)
                    .font(.caption)
                    .lineLimit(Self.quotedLines)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 190, alignment: .leading)
            }
            if comment.state != .working {
                Text(verbatim: status.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 190, alignment: .leading)
            }
            if comments.canSend(comment) {
                Button("Send") { comments.send(comment.id) }
                    .controlSize(.small)
                    .padding(.top, 2)
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

    private var symbol: String {
        switch comment.state {
        case .working: "ellipsis"
        case .declined: "xmark"
        case .queued, .unanswered, .resolved: status.needsOwner ? "exclamationmark" : "clock"
        }
    }

    private var tint: Color {
        if comment.state == .unanswered { return .red }
        if comment.state == .declined { return .gray }
        return status.needsOwner ? .orange : .accentColor
    }
}

struct CanvasCommentPopover: View {
    static let tallest = 360.0

    let comment: CanvasComment
    let comments: CanvasCommentControls

    var body: some View {
        ScrollView {
            CanvasCommentRow(comment: comment, comments: comments)
                .padding(12)
        }
        .frame(width: 300)
        .frame(maxHeight: Self.tallest)
    }
}
