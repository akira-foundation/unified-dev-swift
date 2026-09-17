import SwiftUI
import AppKit

enum FileDrag {
    static func provider(for path: String) -> NSItemProvider? {
        guard FileManager.default.isReadableFile(atPath: path) else { return nil }
        return NSItemProvider(contentsOf: URL(fileURLWithPath: path))
    }
}

private struct FileDragPreview: View {
    var path: String

    private static let side: CGFloat = 32

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: path))
            .resizable()
            .frame(width: Self.side, height: Self.side)
    }
}

private struct FileDragModifier: ViewModifier {
    var path: String

    func body(content: Content) -> some View {
        content.onDrag {
            FileDrag.provider(for: path) ?? NSItemProvider()
        } preview: {
            FileDragPreview(path: path)
        }
    }
}

extension View {
    func fileDrag(path: String) -> some View {
        modifier(FileDragModifier(path: path))
    }
}
