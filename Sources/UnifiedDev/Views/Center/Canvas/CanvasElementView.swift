import SwiftUI
import AppKit
import Core

extension Color {
    init(canvas text: String) {
        guard let parsed = CanvasColour(text) else {
            self = .clear
            return
        }
        self.init(.sRGB, red: parsed.red, green: parsed.green, blue: parsed.blue, opacity: parsed.alpha)
    }
}

struct CanvasElementView: View {
    let element: CanvasElement
    let worktree: String
    let documentPath: String

    var body: some View {
        content
            .frame(width: element.rect.size.width, height: element.rect.size.height)
            .opacity(element.style.opacity)
            .shadow(
                color: element.style.shadow.map { Color(canvas: $0.colour) } ?? .clear,
                radius: element.style.shadow?.radius ?? 0,
                x: element.style.shadow?.offsetX ?? 0,
                y: element.style.shadow?.offsetY ?? 0
            )
            .rotationEffect(.degrees(element.style.rotation))
    }

    @ViewBuilder
    private var content: some View {
        switch element.kind {
        case .text(let text):
            CanvasTextView(text: text)
        case .note(let text):
            CanvasTextView(text: text)
                .padding(12)
                .background(background(defaultFill: "#FFE98A"))
        case .shape(let shape):
            CanvasShapeView(shape: shape.kind, style: element.style)
        case .image(let path):
            CanvasImageView(path: path, worktree: worktree, documentPath: documentPath, style: element.style)
        case .stroke(let stroke):
            CanvasStrokeView(stroke: stroke, rect: element.rect)
        }
    }

    private func background(defaultFill: String) -> some View {
        RoundedRectangle(cornerRadius: element.style.cornerRadius)
            .fill(Color(canvas: element.style.fill ?? defaultFill))
    }
}

struct CanvasTextView: View {
    let text: CanvasText

    var body: some View {
        runs
            .multilineTextAlignment(alignment)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
    }

    private var runs: Text {
        Text(text.runs.reduce(into: AttributedString()) { joined, run in
            var piece = AttributedString(run.text)
            piece.font = .custom(run.fontName, size: run.size).weight(Self.weight(run.weight))
            piece.foregroundColor = Color(canvas: run.colour)
            joined.append(piece)
        })
    }

    private var alignment: TextAlignment {
        switch text.alignment {
        case .leading: .leading
        case .centre: .center
        case .trailing: .trailing
        }
    }

    private static func weight(_ value: Double) -> Font.Weight {
        switch CanvasFontWeight.nearest(to: value) {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }

    private var frameAlignment: Alignment {
        switch text.alignment {
        case .leading: .topLeading
        case .centre: .top
        case .trailing: .topTrailing
        }
    }
}

struct CanvasShapeView: View {
    let shape: CanvasShape.Kind
    let style: CanvasStyle

    var body: some View {
        switch shape {
        case .rectangle:
            RoundedRectangle(cornerRadius: style.cornerRadius).paint(style)
        case .ellipse:
            Ellipse().paint(style)
        case .line:
            CanvasLine(arrow: false).stroke(stroke, lineWidth: style.strokeWidth)
        case .arrow:
            CanvasLine(arrow: true).stroke(stroke, style: StrokeStyle(lineWidth: style.strokeWidth, lineCap: .round, lineJoin: .round))
        }
    }

    private var stroke: Color { Color(canvas: style.stroke ?? "#000000") }
}

private extension Shape {
    func paint(_ style: CanvasStyle) -> some View {
        self.fill(Color(canvas: style.fill ?? "#00000000"))
            .overlay { self.stroke(Color(canvas: style.stroke ?? "#00000000"), lineWidth: style.strokeWidth) }
    }
}

struct CanvasLine: Shape {
    let arrow: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        if arrow {
            let head = min(rect.width, 24)
            path.move(to: CGPoint(x: rect.maxX - head, y: rect.midY - head / 2))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX - head, y: rect.midY + head / 2))
        }
        return path
    }
}

struct CanvasStrokeView: View {
    let stroke: CanvasStroke
    let rect: CanvasRect

    var body: some View {
        Path { path in
            guard let first = stroke.points.first else { return }
            path.move(to: point(first))
            for next in stroke.points.dropFirst() { path.addLine(to: point(next)) }
        }
        .stroke(Color(canvas: stroke.colour), style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round))
    }

    private func point(_ canvas: CanvasPoint) -> CGPoint {
        CGPoint(x: canvas.x - rect.origin.x, y: canvas.y - rect.origin.y)
    }
}

struct CanvasImageView: View {
    let path: String
    let worktree: String
    let documentPath: String
    let style: CanvasStyle

    var body: some View {
        if let image = loaded {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius))
        } else {
            RoundedRectangle(cornerRadius: style.cornerRadius)
                .fill(Color.gray.opacity(0.25))
                .overlay { Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary) }
        }
    }

    private var loaded: NSImage? {
        CanvasImagePath.drawable(path, beside: documentPath, worktree: worktree).flatMap { NSImage(contentsOfFile: $0) }
    }
}
