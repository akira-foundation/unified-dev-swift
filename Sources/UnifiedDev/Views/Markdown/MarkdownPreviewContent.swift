import SwiftUI

struct MarkdownPreviewContent<Content: View>: View {
    let path: String
    let revision: Int
    var height: CGFloat?
    @Binding var isPresented: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        if isPresented {
            MarkdownFilePreview(path: path, revision: revision) { isPresented = false }
                .frame(height: height)
        } else {
            content()
        }
    }
}
