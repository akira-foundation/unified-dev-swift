import SwiftUI
import Core

struct CanvasDraftSlider: View {
    let value: Double
    let range: ClosedRange<Double>
    let commit: (Double) -> Void

    @State private var draft: Double?

    var body: some View {
        Slider(value: Binding(get: { draft ?? value }, set: { draft = $0 }), in: range) { isEditing in
            guard !isEditing, let pending = draft else { return }
            draft = nil
            commit(pending)
        }
        .frame(width: 140)
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
