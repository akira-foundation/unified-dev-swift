import SwiftUI
import Core

struct CanvasCommentTools: View {
    @Binding var tool: CanvasTool
    let comments: CanvasCommentControls
    @Binding var showsList: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Toggle(isOn: Binding(get: { tool == .comment }, set: { tool = $0 ? .comment : .select })) {
                    Image(systemName: CanvasTool.comment.symbol)
                }
                .toggleStyle(.button)
                .help(CanvasTool.comment.title)
                .accessibilityLabel(CanvasTool.comment.title)
                Menu {
                    Button("Show all comments") { showsList = true }
                } label: {
                    Image(systemName: "chevron.down")
                }
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Comment Options")
                .accessibilityLabel("Comment Options")
                if comments.unreadDeclined > 0 {
                    Divider().frame(height: 18)
                    Button("\(comments.unreadDeclined) declined") { showsList = true }
                        .help("Show all comments, with the agent's reason")
                }
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: Capsule())
            if showsList {
                CanvasCommentsList(comments: comments, close: { showsList = false })
                    .frame(width: 320, height: 420)
                    .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
            }
        }
    }
}
