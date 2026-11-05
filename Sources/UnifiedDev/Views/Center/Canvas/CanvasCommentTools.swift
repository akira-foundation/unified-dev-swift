import SwiftUI
import Core

struct CanvasCommentTools: View {
    @Binding var tool: CanvasTool
    let comments: CanvasCommentControls
    @Binding var showsList: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 2) {
                Toggle(isOn: Binding(get: { tool == .comment }, set: { tool = $0 ? .comment : .select })) {
                    Image(systemName: CanvasTool.comment.symbol)
                }
                .toggleStyle(CanvasBarToggleStyle())
                .help(CanvasTool.comment.title)
                .accessibilityLabel(CanvasTool.comment.title)
                CanvasBarMenu(symbol: "chevron.down") {
                    Button("Show all comments") { showsList = true }
                }
                .help("Comment Options")
                .accessibilityLabel("Comment Options")
            }
            .canvasBarBackground()
            if showsList {
                CanvasCommentsList(comments: comments, close: { showsList = false })
                    .frame(width: 320, height: 420)
                    .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
            }
        }
    }
}
