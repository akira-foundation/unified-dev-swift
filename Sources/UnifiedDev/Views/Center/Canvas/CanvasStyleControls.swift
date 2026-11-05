import SwiftUI
import Core

extension EnvironmentValues {
    @Entry var canvasPendingCommits: CanvasPendingCommits?
}

struct CanvasDraftSlider: View {
    let value: Double
    let range: ClosedRange<Double>
    let commit: (Double) -> Void

    @State private var draft: Double?
    @State private var dragging = false
    @State private var coalescer = CanvasCoalescedCommit()
    @Environment(\.canvasPendingCommits) private var pendingCommits

    var body: some View {
        Slider(value: Binding(get: { draft ?? value }, set: { change($0) }), in: range) { isEditing in
            dragging = isEditing
            guard !isEditing else { return }
            coalescer.flush()
            finish()
        }
        .frame(width: 140)
        .onAppear { pendingCommits?.add(coalescer) }
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
    @Environment(\.canvasPendingCommits) private var pendingCommits

    var body: some View {
        ColorPicker(title, selection: Binding(get: { draft ?? colour }, set: { change($0) }), supportsOpacity: supportsOpacity)
            .onAppear { pendingCommits?.add(coalescer) }
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

struct CanvasDraftNumberField: View {
    let title: String
    let value: Binding<Double>
    let format: FloatingPointFormatStyle<Double>
    let width: CGFloat

    var body: some View {
        CanvasDraftTextField(title: title, text: value.wrappedValue.formatted(format), width: width) { typed in
            if let number = CanvasEditing.number(from: typed, format: format) { value.wrappedValue = number }
        }
        .multilineTextAlignment(.trailing)
    }
}

struct CanvasDraftTextField: View {
    let title: String
    let text: String
    let width: CGFloat
    let commit: (String) -> Void

    @State private var typed: String?
    @State private var coalescer = CanvasCoalescedCommit(delay: .seconds(3_600))
    @FocusState private var focused: Bool
    @Environment(\.canvasPendingCommits) private var pendingCommits

    var body: some View {
        TextField(title, text: Binding(get: { typed ?? text }, set: { change($0) }))
            .labelsHidden()
            .frame(width: width)
            .focused($focused)
            .onSubmit { coalescer.flush() }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { coalescer.flush() }
            }
            .onAppear { pendingCommits?.add(coalescer) }
            .onDisappear { coalescer.flush() }
    }

    private func change(_ next: String) {
        typed = next
        coalescer.schedule {
            typed = nil
            commit(next)
        }
    }
}
