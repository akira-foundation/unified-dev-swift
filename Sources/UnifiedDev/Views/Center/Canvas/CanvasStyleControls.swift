import SwiftUI
import Core

struct CanvasDraftSlider: View {
    let value: Double
    let range: ClosedRange<Double>
    let commit: (Double) -> Void

    @State private var draft: Double?
    @State private var dragging = false
    @State private var coalescer = CanvasCoalescedCommit()

    var body: some View {
        Slider(value: Binding(get: { draft ?? value }, set: change), in: range) { isEditing in
            dragging = isEditing
            guard !isEditing else { return }
            coalescer.flush()
            finish()
        }
        .frame(width: 140)
        .onDisappear {
            coalescer.flush()
            finish()
        }
    }

    private func change(_ next: Double) {
        draft = next
        guard !dragging else { return }
        coalescer.schedule(finish)
    }

    private func finish() {
        guard let pending = draft else { return }
        draft = nil
        commit(pending)
    }
}

struct CanvasColourWell: View {
    let title: String
    let colour: Color
    let supportsOpacity: Bool
    let immediate: Bool
    let commit: (Color) -> Void

    @State private var draft: Color?
    @State private var coalescer = CanvasCoalescedCommit()

    var body: some View {
        ColorPicker(title, selection: Binding(get: { draft ?? colour }, set: change), supportsOpacity: supportsOpacity)
            .onDisappear { coalescer.flush() }
    }

    private func change(_ next: Color) {
        guard !immediate else {
            commit(next)
            return
        }
        draft = next
        coalescer.schedule {
            draft = nil
            commit(next)
        }
    }
}
