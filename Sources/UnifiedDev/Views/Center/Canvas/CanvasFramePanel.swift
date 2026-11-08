import SwiftUI
import Core

struct CanvasFramePanel: View {
    let frame: CanvasFrame
    let update: ((CanvasDocument) -> [CanvasOperation]) -> Void
    let delete: () -> Void

    private var id: CanvasFrameID { frame.id }

    var body: some View {
        Form {
            Section("Frame") {
                LabeledContent("Name") {
                    CanvasDraftTextField(title: "Name", text: frame.name, width: 150) { name in
                        update { CanvasFrameEdit.operations(renaming: id, to: name, in: $0) }
                    }
                }
                LabeledContent("Fill") {
                    CanvasColourWell(title: "Fill", colour: Color(canvas: frame.fill), supportsOpacity: true, immediate: false) { colour in
                        update { CanvasFrameEdit.operations(filling: id, with: colour.canvasHex, in: $0) }
                    }
                    .labelsHidden()
                }
            }
            Section {
                coordinate("X", frame.rect.origin.x) { x, document in CanvasFrameEdit.operations(placing: id, x: x, in: document) }
                coordinate("Y", frame.rect.origin.y) { y, document in CanvasFrameEdit.operations(placing: id, y: y, in: document) }
                CanvasFrameSizeRows(frame: frame, update: update)
            } header: {
                Text("Position and Size")
            } footer: {
                Text("Slides play and export from left to right.")
            }
            Section {
                Button("Delete Frame", systemImage: "trash", role: .destructive, action: delete)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func coordinate(
        _ title: String, _ value: Double, _ operations: @escaping (Double, CanvasDocument) -> [CanvasOperation]
    ) -> some View {
        LabeledContent(title) {
            CanvasDraftNumberField(
                title: title,
                value: Binding(get: { value }, set: { next in update { operations(next, $0) } }),
                format: .number.grouping(.never).precision(.fractionLength(0...1)),
                width: 80
            )
        }
    }
}

struct CanvasFrameSizeRows: View {
    let frame: CanvasFrame
    let update: ((CanvasDocument) -> [CanvasOperation]) -> Void

    var body: some View {
        LabeledContent("Width") { field("Width", \.width) }
        LabeledContent("Height") { field("Height", \.height) }
    }

    private func field(_ title: String, _ side: WritableKeyPath<CanvasSize, Double>) -> some View {
        CanvasDraftNumberField(
            title: title,
            value: Binding(
                get: { frame.rect.size[keyPath: side] },
                set: { value in
                    update { document in
                        guard var size = document.frames.first(where: { $0.id == frame.id })?.rect.size else { return [] }
                        size[keyPath: side] = value
                        return CanvasFrameSize.operations(resizing: frame.id, to: size, in: document)
                    }
                }
            ),
            format: .number.grouping(.never).precision(.fractionLength(0)),
            width: 80
        )
    }
}
