import SwiftUI
import Core

struct CanvasPlaybackView: View {
    let document: CanvasDocument
    let worktree: String
    let documentPath: String
    let close: () -> Void

    @State private var playback: CanvasPlayback

    init(document: CanvasDocument, worktree: String, documentPath: String, close: @escaping () -> Void) {
        self.document = document
        self.worktree = worktree
        self.documentPath = documentPath
        self.close = close
        _playback = State(initialValue: CanvasPlayback(frames: document.frames))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(Color(nsColor: .underPageBackgroundColor))
            if let frame = playback.frame {
                slide(frame)
            } else {
                ContentUnavailableView("No frames", systemImage: "rectangle.dashed", description: Text("Add a frame to play it."))
            }
            controls
        }
        .contentShape(Rectangle())
        .onChange(of: document.frames) { _, frames in playback.update(frames: frames) }
    }

    private func slide(_ frame: CanvasFrame) -> some View {
        GeometryReader { proxy in
            let size = frame.rect.size
            let available = CanvasSize(width: proxy.size.width - 48, height: proxy.size.height - 120)
            let scale = max(CanvasPlayback.fitScale(of: size, in: available), 0.01)
            CanvasFrameView(
                frame: frame,
                elements: document.elements(in: frame.id),
                worktree: worktree,
                documentPath: documentPath
            )
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
            .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
            .position(x: proxy.size.width / 2, y: (proxy.size.height - 72) / 2 + 12)
        }
        .id(frame.id)
    }

    private var controls: some View {
        HStack(spacing: 2) {
            Button { playback.previous() } label: { Image(systemName: "chevron.left") }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(playback.isAtStart)
                .help("Previous Frame")
                .accessibilityLabel("Previous Frame")
            Text(position)
                .monospacedDigit()
                .frame(minWidth: 64)
                .accessibilityLabel(position)
            Button { playback.next() } label: { Image(systemName: "chevron.right") }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(playback.isAtEnd)
                .help("Next Frame")
                .accessibilityLabel("Next Frame")
            CanvasBarDivider()
            Button(action: close) { Image(systemName: "xmark") }
                .keyboardShortcut(.cancelAction)
                .help("Stop Playing")
                .accessibilityLabel("Stop Playing")
        }
        .buttonStyle(CanvasBarButtonStyle())
        .canvasBarBackground()
        .padding(.bottom, 16)
    }

    private var position: String {
        playback.count == 0 ? "0 of 0" : "\(playback.current + 1) of \(playback.count)"
    }
}
