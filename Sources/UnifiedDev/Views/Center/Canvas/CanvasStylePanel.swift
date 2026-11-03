import AppKit
import SwiftUI
import Core

struct CanvasStylePanel: View {
    let elements: [CanvasElement]
    let document: CanvasDocument
    let editing: CanvasTextEditing?
    let apply: ([CanvasOperation]) -> Void
    let update: ((CanvasDocument) -> [CanvasOperation]) -> Void

    private static let families = NSFontManager.shared.availableFontFamilies

    private var first: CanvasElement? { elements.first }
    private var texts: [(element: CanvasElement, text: CanvasText)] {
        elements.compactMap { element in element.text.map { (element, $0) } }
    }
    private var frame: CanvasFrame? {
        first?.frameID.flatMap { id in document.frames.first { $0.id == id } }
    }
    private var run: CanvasTextRun? { (editing?.text ?? texts.first?.text)?.runs.first }
    private var supportsFill: Bool {
        elements.contains { element in
            switch element.kind {
            case .shape, .note, .image: true
            default: false
            }
        }
    }

    var body: some View {
        Form {
            if let run {
                Section("Text") {
                    Picker("Font", selection: font(run)) {
                        ForEach(families(keeping: run.fontName), id: \.self) { Text($0).tag($0) }
                    }
                    LabeledContent("Size") {
                        HStack {
                            CanvasDraftNumberField(title: "Size", value: size(run), format: .number.precision(.fractionLength(0...1)), width: 56)
                            Stepper("Size", value: size(run), in: 1...512).labelsHidden()
                        }
                    }
                    Picker("Weight", selection: weight(run)) {
                        ForEach(CanvasFontWeight.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    CanvasColourWell(
                        title: "Colour", colour: Color(canvas: run.colour), supportsOpacity: false,
                        immediate: editing != nil
                    ) { change(CanvasRunChange(colour: $0.canvasHex)) }
                }
            }
            if let style = first?.style {
                Section("Appearance") {
                    if supportsFill {
                        LabeledContent("Fill") {
                            HStack {
                                CanvasColourWell(
                                    title: "Fill", colour: Color(canvas: style.fill ?? "#00000000"), supportsOpacity: true, immediate: false
                                ) { restyle(CanvasStylePatch(fill: $0.canvasHex)) }
                                .labelsHidden()
                                Button("Clear") { restyle(CanvasStylePatch(clearFill: true)) }
                                    .disabled(style.fill == nil)
                            }
                        }
                    }
                    LabeledContent("Corners") {
                        CanvasDraftSlider(value: style.cornerRadius, range: 0...200) { restyle(CanvasStylePatch(cornerRadius: $0)) }
                    }
                    LabeledContent("Opacity") {
                        CanvasDraftSlider(value: style.opacity, range: 0...1) { restyle(CanvasStylePatch(opacity: $0)) }
                    }
                    LabeledContent("Rotation") {
                        HStack {
                            CanvasDraftNumberField(
                                title: "Rotation", value: number(style.rotation) { CanvasStylePatch(rotation: $0) },
                                format: .number.precision(.fractionLength(0...1)), width: 56
                            )
                            Stepper("Rotation", value: number(style.rotation) { CanvasStylePatch(rotation: $0) }, in: -360...360)
                                .labelsHidden()
                        }
                    }
                }
                Section("Shadow") {
                    Toggle("Shadow", isOn: shadowEnabled(style))
                    LabeledContent("Blur") {
                        CanvasDraftSlider(value: style.shadow?.radius ?? 0, range: 0...80) {
                            restyle(CanvasStylePatch(shadow: CanvasShadowPatch(radius: $0)))
                        }
                        .disabled(style.shadow == nil)
                    }
                }
            }
            if let frame {
                Section("Frame") {
                    LabeledContent("Width") {
                        CanvasDraftNumberField(
                            title: "Width", value: frameSide(frame, \.width),
                            format: .number.grouping(.never).precision(.fractionLength(0)), width: 80
                        )
                    }
                    LabeledContent("Height") {
                        CanvasDraftNumberField(
                            title: "Height", value: frameSide(frame, \.height),
                            format: .number.grouping(.never).precision(.fractionLength(0)), width: 80
                        )
                    }
                }
            }
            Section("Order") {
                LabeledContent("Stacking") {
                    HStack {
                        ForEach(CanvasStackingDirection.allCases, id: \.self) { direction in
                            Button { restack(direction) } label: { Image(systemName: direction.symbol) }
                                .buttonStyle(.borderless)
                                .help(direction.title)
                                .accessibilityLabel(direction.title)
                        }
                    }
                    .disabled(elements.count != 1)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func families(keeping name: String) -> [String] {
        Self.families.contains(name) ? Self.families : [name] + Self.families
    }

    private func restyle(_ patch: CanvasStylePatch) {
        apply(elements.map { .updateElement($0.id, expectedRevision: nil, CanvasElementPatch(style: patch)) })
    }

    private func change(_ change: CanvasRunChange) {
        if let editing {
            editing.apply(change)
            return
        }
        let ids = texts.map(\.element.id)
        update { CanvasTextStyling.operations(applying: change, to: ids, in: $0) }
    }

    private func restack(_ direction: CanvasStackingDirection) {
        guard let id = first?.id else { return }
        apply(CanvasStacking.operations(moving: id, direction, in: document))
    }

    private func font(_ run: CanvasTextRun) -> Binding<String> {
        Binding(get: { run.fontName }, set: { change(CanvasRunChange(fontName: $0)) })
    }

    private func size(_ run: CanvasTextRun) -> Binding<Double> {
        Binding(get: { run.size }, set: { change(CanvasRunChange(size: min(max($0, 1), 512))) })
    }

    private func weight(_ run: CanvasTextRun) -> Binding<CanvasFontWeight> {
        Binding(
            get: { CanvasFontWeight.nearest(to: run.weight) },
            set: { change(CanvasRunChange(weight: $0.value)) }
        )
    }

    private func frameSide(_ frame: CanvasFrame, _ side: KeyPath<CanvasSize, Double>) -> Binding<Double> {
        Binding(
            get: { frame.rect.size[keyPath: side] },
            set: { value in
                update { document in
                    guard var size = document.frames.first(where: { $0.id == frame.id })?.rect.size else { return [] }
                    if side == \CanvasSize.width { size.width = value } else { size.height = value }
                    return CanvasFrameSize.operations(resizing: frame.id, to: size, in: document)
                }
            }
        )
    }

    private func number(_ value: Double, _ patch: @escaping (Double) -> CanvasStylePatch) -> Binding<Double> {
        Binding(get: { value }, set: { restyle(patch($0)) })
    }

    private func shadowEnabled(_ style: CanvasStyle) -> Binding<Bool> {
        Binding(
            get: { style.shadow != nil },
            set: {
                restyle($0
                    ? CanvasStylePatch(shadow: CanvasShadowPatch(offsetX: 0, offsetY: 8, radius: 16, colour: "#00000066"))
                    : CanvasStylePatch(clearShadow: true))
            }
        )
    }
}

extension Color {
    var canvasHex: String {
        let converted = NSColor(self).usingColorSpace(.sRGB) ?? .black
        return CanvasColour(
            red: converted.redComponent, green: converted.greenComponent, blue: converted.blueComponent, alpha: converted.alphaComponent
        ).hex
    }
}

private extension CanvasFontWeight {
    var title: String {
        switch self {
        case .ultraLight: "Ultra Light"
        case .thin: "Thin"
        case .light: "Light"
        case .regular: "Regular"
        case .medium: "Medium"
        case .semibold: "Semibold"
        case .bold: "Bold"
        case .heavy: "Heavy"
        case .black: "Black"
        }
    }
}

private extension CanvasStackingDirection {
    var title: String {
        switch self {
        case .toBack: "Send to Back"
        case .backward: "Send Backward"
        case .forward: "Bring Forward"
        case .toFront: "Bring to Front"
        }
    }

    var symbol: String {
        switch self {
        case .toBack: "square.3.layers.3d.bottom.filled"
        case .backward: "arrow.down"
        case .forward: "arrow.up"
        case .toFront: "square.3.layers.3d.top.filled"
        }
    }
}
