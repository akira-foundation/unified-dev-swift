import SwiftUI

enum CanvasTool: String, CaseIterable, Identifiable {
    case select, hand, text, note, shape, pen, image

    var id: String { rawValue }

    var title: String {
        switch self {
        case .select: "Select"
        case .hand: "Hand"
        case .text: "Text"
        case .note: "Note"
        case .shape: "Shape"
        case .pen: "Pen"
        case .image: "Image"
        }
    }

    var symbol: String {
        switch self {
        case .select: "cursorarrow"
        case .hand: "hand.raised"
        case .text: "textformat"
        case .note: "note.text"
        case .shape: "square"
        case .pen: "pencil.tip"
        case .image: "photo"
        }
    }

    var isAvailable: Bool { self == .hand }
}

struct CanvasToolbar: View {
    @Binding var tool: CanvasTool
    let zoom: Double
    let zoomIn: () -> Void
    let zoomOut: () -> Void
    let fit: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(CanvasTool.allCases) { candidate in
                Toggle(isOn: Binding(get: { tool == candidate }, set: { if $0 { tool = candidate } })) {
                    Image(systemName: candidate.symbol)
                }
                .toggleStyle(.button)
                .buttonStyle(.borderless)
                .disabled(!candidate.isAvailable)
                .help(candidate.title)
                .accessibilityLabel(candidate.title)
            }
            Divider().frame(height: 18)
            Button(action: zoomOut) { Image(systemName: "minus") }
                .help("Zoom Out")
                .accessibilityLabel("Zoom Out")
            Button(action: fit) { Text(zoom, format: .percent.precision(.fractionLength(0))).monospacedDigit() }
                .help("Zoom to Fit")
                .accessibilityLabel("Zoom to Fit")
            Button(action: zoomIn) { Image(systemName: "plus") }
                .help("Zoom In")
                .accessibilityLabel("Zoom In")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: Capsule())
    }
}
