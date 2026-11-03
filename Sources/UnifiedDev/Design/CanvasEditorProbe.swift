import AppKit
import SwiftUI
import Core

#if DEBUG
@MainActor
enum CanvasEditorProbe {
    private static let flag = "--canvas-editor-probe"

    static var isRequested: Bool { CommandLine.arguments.contains(flag) }

    static func runAndExit() -> Never {
        NSApplication.shared.setActivationPolicy(.prohibited)
        NSApplication.shared.finishLaunching()
        let directory = ProbeHarness.text(flag, or: NSTemporaryDirectory() + "unifieddev-canvas-editor")
        var failures: [String] = []
        do {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            let model = CanvasDocumentModel(path: directory + "/deck.udcanvas", worktree: directory)
            for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                let content = CanvasEditorView(model: model, revision: 0).frame(width: 900, height: 700)
                failures += shoot(content, appearance: appearance, to: "\(directory)/editor-\(name).png")
                if case .document(let document) = model.document {
                    let selected = CanvasSurface(
                        document: document,
                        worktree: directory,
                        documentPath: model.path,
                        apply: { _ in },
                        initialTool: .select,
                        initialSelection: [CanvasElementID("e2"), CanvasElementID("e3")],
                        initialGuides: [CanvasGuide(axis: .vertical, position: 540, from: 120, to: 1_160)]
                    )
                    .frame(width: 900, height: 700)
                    failures += shoot(selected, appearance: appearance, to: "\(directory)/selected-\(name).png")
                    let single = CanvasSurface(
                        document: document,
                        worktree: directory,
                        documentPath: model.path,
                        apply: { _ in },
                        initialTool: .select,
                        initialSelection: [CanvasElementID("e3")]
                    )
                    .frame(width: 900, height: 700)
                    failures += shoot(single, appearance: appearance, to: "\(directory)/single-\(name).png")
                }
            }
            if case .document(let document) = model.document, let frame = document.frames.first {
                let frameView = CanvasFrameView(
                    frame: frame,
                    elements: document.elements.filter { $0.frameID == frame.id },
                    worktree: directory,
                    documentPath: model.path
                )
                let renderer = ImageRenderer(content: frameView)
                if let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                   let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                    try png.write(to: URL(filePath: directory + "/frame.png"))
                } else {
                    failures.append("the frame did not render")
                }
            } else {
                failures.append("no document in \(model.path)")
            }
        } catch {
            failures.append("\(error)")
        }
        for failure in failures { FileHandle.standardError.write(Data((failure + "\n").utf8)) }
        exit(failures.isEmpty ? 0 : 1)
    }

    private static func shoot(_ content: some View, appearance: NSAppearance.Name, to path: String) -> [String] {
        let controller = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.borderless]
        window.appearance = NSAppearance(named: appearance)
        window.setContentSize(NSSize(width: 900, height: 700))
        window.setFrameOrigin(NSPoint(x: -9_000, y: -9_000))
        window.orderFront(nil)
        for _ in 0..<5 {
            controller.view.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        }
        let view = controller.view
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return ["\(path): no bitmap"] }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        window.orderOut(nil)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { return ["\(path): not a png"] }
        do {
            try png.write(to: URL(filePath: path))
            return []
        } catch {
            return ["\(path): \(error)"]
        }
    }
}
#endif
