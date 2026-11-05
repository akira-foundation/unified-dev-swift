import AppKit
import SwiftUI
import Core

#if DEBUG
@MainActor
enum CanvasRenderProbe {
    static func run(in directory: String) -> [String] {
        var failures: [String] = []
        func check(_ condition: Bool, _ message: String) {
            if !condition { failures.append("render: \(message)") }
        }
        let imagePath = directory + "/render-probe-red.png"
        guard writeSolidPNG(.red, to: imagePath) else { return ["render: could not write \(imagePath)"] }

        let frame = CanvasFrame(name: "Probe", rect: CanvasRect(x: 0, y: 0, width: 400, height: 300))
        let title = CanvasElement(
            frameID: frame.id, rect: CanvasRect(x: 20, y: 20, width: 200, height: 40),
            kind: .text(CanvasText(runs: [CanvasTextRun(text: "Probe", fontName: "Helvetica", size: 32, weight: 700, colour: "#000000")]))
        )
        let picture = CanvasElement(
            frameID: frame.id, rect: CanvasRect(x: 20, y: 100, width: 80, height: 80),
            kind: .image(path: "render-probe-red.png")
        )
        let box = CanvasElement(
            frameID: frame.id, rect: CanvasRect(x: 200, y: 100, width: 80, height: 80),
            style: CanvasStyle(fill: "#0000FF"), kind: .shape(CanvasShape(kind: .rectangle))
        )
        let ghost = CanvasElement(
            frameID: frame.id, rect: CanvasRect(x: 20, y: 220, width: 200, height: 30),
            kind: .text(CanvasText(runs: [CanvasTextRun(text: "Ghost", fontName: "No Such Font Anywhere", size: 20, weight: 400, colour: "#000000")]))
        )
        let document = CanvasDocument(frames: [frame], elements: [title, picture, box, ghost])

        guard let png = CanvasFrameRenderer.png(frame: frame, document: document, documentPath: directory + "/probe.udcanvas", worktree: directory),
              let rendered = NSBitmapImageRep(data: png) else { return failures + ["render: no picture"] }
        check(rendered.pixelsWide == 400 && rendered.pixelsHigh == 300, "size is \(rendered.pixelsWide) by \(rendered.pixelsHigh), not 400 by 300")
        check(isNear(rendered, 240, 140, .blue), "the shape is not blue at its centre")
        check(isNear(rendered, 60, 140, .red), "the image is not red at its centre")
        check(isNear(rendered, 390, 290, .white), "the frame is not white away from its elements")
        check(hasInk(rendered, x: 20..<140, y: 20..<60), "the text drew nothing")

        let onScreen = onScreenPicture(
            CanvasFrameView(frame: frame, elements: document.elements, worktree: directory, documentPath: directory + "/probe.udcanvas")
        )
        if let onScreen {
            let scale = onScreen.pixelsWide / rendered.pixelsWide
            check(scale >= 1 && onScreen.pixelsWide == rendered.pixelsWide * scale && onScreen.pixelsHigh == rendered.pixelsHigh * scale, "the view is a different size")
            let difference = meanDifference(rendered, onScreen, scale: max(scale, 1))
            check(difference < 0.01, "the picture differs from the view by \(difference)")
        } else {
            failures.append("render: the view did not draw")
        }

        if let half = CanvasFrameRenderer.png(
            frame: frame, document: document, documentPath: directory + "/probe.udcanvas", worktree: directory, scale: 0.5
        ), let reduced = NSBitmapImageRep(data: half) {
            check(reduced.pixelsWide == 200 && reduced.pixelsHigh == 150, "half scale is \(reduced.pixelsWide) by \(reduced.pixelsHigh)")
        } else {
            failures.append("render: no half scale picture")
        }

        check(CanvasFrameRenderer.missingFonts(in: frame, of: document) == ["No Such Font Anywhere"], "the missing font was not named")
        try? FileManager.default.removeItem(atPath: imagePath)
        return failures
    }

    private static func writeSolidPNG(_ colour: NSColor, to path: String) -> Bool {
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            colour.setFill()
            rect.fill()
            return true
        }
        guard let tiff = image.tiffRepresentation,
              let data = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return false }
        return (try? data.write(to: URL(filePath: path))) != nil
    }

    private static func onScreenPicture(_ content: some View) -> NSBitmapImageRep? {
        let controller = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.borderless]
        window.appearance = NSAppearance(named: .aqua)
        window.setContentSize(NSSize(width: 400, height: 300))
        window.setFrameOrigin(NSPoint(x: -9_000, y: -9_000))
        window.orderFront(nil)
        for _ in 0..<5 {
            controller.view.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        }
        let view = controller.view
        defer { window.orderOut(nil) }
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return bitmap
    }

    private static func isNear(_ bitmap: NSBitmapImageRep, _ x: Int, _ y: Int, _ expected: NSColor) -> Bool {
        guard let actual = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.genericRGB),
              let wanted = expected.usingColorSpace(.genericRGB) else { return false }
        return abs(actual.redComponent - wanted.redComponent) < 0.08
            && abs(actual.greenComponent - wanted.greenComponent) < 0.08
            && abs(actual.blueComponent - wanted.blueComponent) < 0.08
    }

    private static func hasInk(_ bitmap: NSBitmapImageRep, x: Range<Int>, y: Range<Int>) -> Bool {
        for row in y {
            for column in x where !isNear(bitmap, column, row, .white) { return true }
        }
        return false
    }

    private static func meanDifference(_ first: NSBitmapImageRep, _ second: NSBitmapImageRep, scale: Int) -> Double {
        var total = 0.0
        for row in 0..<first.pixelsHigh {
            for column in 0..<first.pixelsWide {
                guard let one = first.colorAt(x: column, y: row)?.usingColorSpace(.genericRGB),
                      let two = second.colorAt(x: column * scale, y: row * scale)?.usingColorSpace(.genericRGB) else { continue }
                total += abs(one.redComponent - two.redComponent) + abs(one.greenComponent - two.greenComponent)
                    + abs(one.blueComponent - two.blueComponent)
            }
        }
        return total / Double(first.pixelsWide * first.pixelsHigh * 3)
    }
}
#endif
