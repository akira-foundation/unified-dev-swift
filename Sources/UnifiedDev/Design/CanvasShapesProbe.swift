import AppKit
import SwiftUI
import Core

#if DEBUG
@MainActor
enum CanvasShapesProbe {
    private static let origin = CGPoint(x: 60, y: 80)
    private static let window = NSSize(width: 900, height: 600)

    static func run(in directory: String) -> [String] {
        var failures: [String] = []
        let shots = directory + "/shapes"
        try? FileManager.default.createDirectory(atPath: shots, withIntermediateDirectories: true)
        let (document, frame) = sample()
        let path = directory + "/shapes.udcanvas"
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            let surface = CanvasSurface(
                document: document, worktree: directory, documentPath: path, apply: { _ in },
                initialTool: .select, initialViewport: CanvasViewport(zoom: 1, offset: CanvasPoint(x: origin.x, y: origin.y))
            )
            .frame(width: window.width, height: window.height)
            let screen = "\(shots)/screen-\(name).png"
            failures += CanvasEditorProbe.shoot(surface, appearance: appearance, to: screen, size: window)
            let playback = CanvasPlaybackView(document: document, worktree: directory, documentPath: path, close: {})
                .frame(width: window.width, height: window.height)
            failures += CanvasEditorProbe.shoot(playback, appearance: appearance, to: "\(shots)/playback-\(name).png", size: window)
            failures += compare(screen: screen, document: document, frame: frame, path: path, directory: directory, name: name, to: shots)
        }
        return failures
    }

    private static func compare(
        screen: String, document: CanvasDocument, frame: CanvasFrame, path: String, directory: String, name: String, to shots: String
    ) -> [String] {
        guard let screenData = FileManager.default.contents(atPath: screen), let shot = NSBitmapImageRep(data: screenData) else {
            return ["shapes: no screen picture for \(name)"]
        }
        let ratio = Double(shot.pixelsWide) / window.width
        guard let png = CanvasFrameRenderer.png(frame: frame, document: document, documentPath: path, worktree: directory, scale: ratio),
              let rendered = NSBitmapImageRep(data: png) else { return ["shapes: no render for \(name)"] }
        try? png.write(to: URL(filePath: "\(shots)/render-\(name).png"))
        var mismatched = 0
        var drawn = 0
        let width = rendered.pixelsWide
        let height = rendered.pixelsHigh
        func isInk(_ colour: NSColor?) -> Bool {
            guard let colour = colour?.usingColorSpace(.sRGB) else { return false }
            return 1 - (colour.redComponent + colour.greenComponent + colour.blueComponent) / 3 > 0.12
        }
        for y in 0..<height {
            for x in 0..<width {
                let inRender = isInk(rendered.colorAt(x: x, y: y))
                let onScreen = isInk(shot.colorAt(x: x + Int(origin.x * ratio), y: y + Int(origin.y * ratio)))
                if inRender { drawn += 1 }
                if inRender != onScreen { mismatched += 1 }
            }
        }
        let share = Double(mismatched) / Double(max(drawn, 1))
        FileHandle.standardError.write(Data("shapes: \(name) drew \(drawn) pixels, \(mismatched) differ (\(share))\n".utf8))
        return drawn > 0 && share < 0.01 ? [] : ["shapes: the render differs from the screen in \(name): \(mismatched) of \(drawn) pixels"]
    }

    private static func sample() -> (CanvasDocument, CanvasFrame) {
        let frame = CanvasFrame(id: CanvasFrameID("slide"), name: "Slide", rect: CanvasRect(x: 0, y: 0, width: 600, height: 400))
        func put(_ id: String, _ rect: CanvasRect, _ style: CanvasStyle, _ kind: CanvasElement.Kind) -> CanvasElement {
            CanvasElement(id: CanvasElementID(id), frameID: frame.id, rect: rect, style: style, kind: kind)
        }
        func run(_ text: String, _ size: Double) -> CanvasText {
            CanvasText(runs: [CanvasTextRun(text: text, fontName: "Helvetica Neue", size: size, weight: 400, colour: "#111827")])
        }
        let wave = (0...40).map { CanvasPoint(x: 4 + Double($0) * 4, y: 24 + 18 * sin(Double($0) / 3)) }
        let elements = [
            put("title", CanvasRect(x: 24, y: 16, width: 300, height: 48), CanvasStyle(), .text(run("Shapes and notes", 32))),
            put("note", CanvasRect(x: 24, y: 80, width: 200, height: 120), CanvasStyle(fill: "#FFE98A", cornerRadius: 8), .note(run("A sticky note", 24))),
            put("rectangle", CanvasRect(x: 250, y: 80, width: 140, height: 90), CanvasStyle(fill: "#BFDBFE", stroke: "#1D4ED8", strokeWidth: 6, cornerRadius: 12), .shape(CanvasShape(kind: .rectangle))),
            put("ellipse", CanvasRect(x: 420, y: 80, width: 140, height: 90), CanvasStyle(stroke: "#B91C1C", strokeWidth: 6), .shape(CanvasShape(kind: .ellipse))),
            put("line", CanvasRect(x: 250, y: 200, width: 140, height: 24), CanvasStyle(stroke: "#111827", strokeWidth: 6, rotation: 20), .shape(CanvasShape(kind: .line))),
            put("arrow", CanvasRect(x: 420, y: 200, width: 140, height: 24), CanvasStyle(stroke: "#047857", strokeWidth: 6, rotation: -20), .shape(CanvasShape(kind: .arrow))),
            put("pen", CanvasRect(x: 24, y: 230, width: 172, height: 56), CanvasStyle(), .stroke(CanvasStroke(points: wave, width: 8, colour: "#7C3AED"))),
            put("dot", CanvasRect(x: 230, y: 300, width: 20, height: 20), CanvasStyle(), .stroke(CanvasStroke(points: [CanvasPoint(x: 10, y: 10)], width: 20, colour: "#EA580C"))),
        ]
        return (CanvasDocument(frames: [frame], elements: elements), frame)
    }
}
#endif
