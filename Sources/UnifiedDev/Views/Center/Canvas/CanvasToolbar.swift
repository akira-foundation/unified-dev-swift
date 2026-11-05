import SwiftUI
import Core

enum CanvasTool: String, CaseIterable, Identifiable {
    case select, hand, text, note, shape, pen, comment

    static let floatingBar: [CanvasTool] = [.select, .hand, .text, .note, .shape, .pen]

    var id: String { rawValue }

    var pansWithOption: Bool { self == .note || self == .shape || self == .pen }

    var title: String {
        switch self {
        case .select: "Select"
        case .hand: "Hand"
        case .text: "Text"
        case .note: "Note"
        case .shape: "Shape"
        case .pen: "Pen"
        case .comment: "Add Comment"
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
        case .comment: "text.bubble"
        }
    }
}

struct CanvasToolbar: View {
    @Binding var tool: CanvasTool
    @Binding var shapeKind: CanvasShape.Kind
    let zoom: Double
    let zoomIn: () -> Void
    let zoomOut: () -> Void
    let fit: () -> Void
    let addFrame: (CanvasFramePreset) -> Void
    let addImage: () -> Void
    let canAddImage: Bool
    let exportFrames: () -> Void
    let canExport: Bool
    let play: () -> Void
    let canPlay: Bool

    var body: some View {
        HStack(spacing: 2) {
            tools
            CanvasBarDivider()
            CanvasFrameCreation(add: addFrame)
            Button(action: addImage) { Image(systemName: "photo") }
                .disabled(!canAddImage)
                .help("Add Image")
                .accessibilityLabel("Add Image")
            Button(action: exportFrames) { Image(systemName: "square.and.arrow.up") }
                .disabled(!canExport)
                .help("Export Frames as PNG")
                .accessibilityLabel("Export Frames as PNG")
            Button(action: play) { Image(systemName: "play.fill") }
                .disabled(!canPlay)
                .help("Play Frames")
                .accessibilityLabel("Play Frames")
            CanvasBarDivider()
            Button(action: zoomOut) { Image(systemName: "minus") }
                .help("Zoom Out")
                .accessibilityLabel("Zoom Out")
            Button(action: fit) {
                Text(zoom, format: .percent.precision(.fractionLength(0)))
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .frame(minWidth: 40)
            }
            .help("Zoom to Fit")
            .accessibilityLabel("Zoom to Fit")
            Button(action: zoomIn) { Image(systemName: "plus") }
                .help("Zoom In")
                .accessibilityLabel("Zoom In")
        }
        .buttonStyle(CanvasBarButtonStyle())
        .canvasBarBackground()
    }

    @ViewBuilder
    private var tools: some View {
        ForEach(CanvasTool.floatingBar) { candidate in
            Toggle(isOn: Binding(get: { tool == candidate }, set: { if $0 { tool = candidate } })) {
                Image(systemName: candidate == .shape ? shapeKind.symbol : candidate.symbol)
            }
            .toggleStyle(CanvasBarToggleStyle())
            .help(candidate.title)
            .accessibilityLabel(candidate.title)
        }
        if tool == .shape {
            CanvasBarMenu(symbol: "chevron.down") {
                Picker("Shape", selection: $shapeKind) {
                    ForEach(CanvasShape.Kind.allCases, id: \.self) { kind in
                        Label(kind.title, systemImage: kind.symbol).tag(kind)
                    }
                }
                .pickerStyle(.inline)
            }
            .help("Shape Type")
            .accessibilityLabel("Shape Type")
        }
    }
}
