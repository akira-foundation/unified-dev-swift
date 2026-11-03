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
                    let rotated = CanvasSurface(
                        document: document,
                        worktree: directory,
                        documentPath: model.path,
                        apply: { _ in },
                        initialTool: .select,
                        initialSelection: [CanvasElementID("e2")]
                    )
                    .frame(width: 900, height: 700)
                    failures += shoot(rotated, appearance: appearance, to: "\(directory)/rotated-\(name).png")
                    let styled = CanvasSurface(
                        document: document,
                        worktree: directory,
                        documentPath: model.path,
                        apply: { _ in },
                        initialTool: .select,
                        initialSelection: [CanvasElementID("e1")]
                    )
                    .frame(width: 1_200, height: 800)
                    failures += shoot(styled, appearance: appearance, to: "\(directory)/panel-text-\(name).png", size: NSSize(width: 1_200, height: 800))
                    let shape = CanvasSurface(
                        document: document,
                        worktree: directory,
                        documentPath: model.path,
                        apply: { _ in },
                        initialTool: .select,
                        initialSelection: [CanvasElementID("e2")]
                    )
                    .frame(width: 1_200, height: 800)
                    failures += shoot(shape, appearance: appearance, to: "\(directory)/panel-shape-\(name).png", size: NSSize(width: 1_200, height: 800))
                    let typing = CanvasSurface(
                        document: document,
                        worktree: directory,
                        documentPath: model.path,
                        apply: { _ in },
                        editing: document.elements.first { $0.id == CanvasElementID("e1") }?.text.map {
                            CanvasTextEditing(elementID: CanvasElementID("e1"), text: $0)
                        },
                        initialTool: .select,
                        initialSelection: [CanvasElementID("e1")]
                    )
                    .frame(width: 1_200, height: 800)
                    failures += shoot(typing, appearance: appearance, to: "\(directory)/editing-\(name).png", size: NSSize(width: 1_200, height: 800))
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
            let warnings: [(String, CanvasDiskWarning)] = [
                ("saved", .saveFailed("The disk is full.")),
                ("refused", .refused("The file on disk was saved as version 9, and this Unified Dev reads up to version 1.")),
                ("vanished", .vanished),
                ("reloaded", .reloaded(
                    backups: [directory + "/deck.udcanvas.backup-20261103T101500+0000", directory + "/deck.udcanvas.backup-20261103T101640+0000"],
                    typingKeptIn: [directory + "/deck.udcanvas.backup-20261103T101500+0000"]
                )),
            ]
            for (name, warning) in warnings {
                let strip = NoticePiece(tone: warning.tone) {
                    VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                        Text(verbatim: warning.title).font(Typo.labelEmphasis)
                        Text(verbatim: warning.message).font(Typo.caption).foregroundStyle(Palette.textSecondary)
                    }
                } actions: {
                    ForEach(warning.actions, id: \.self) { Button($0.title) {} }.controlSize(.small)
                }
                .frame(width: 900, height: 120)
                failures += shoot(strip, appearance: .aqua, to: "\(directory)/warning-\(name).png", size: NSSize(width: 900, height: 120))
            }
            failures += CanvasSavingProbe.run(in: directory)
            failures += CanvasRenderProbe.run(in: directory)
        } catch {
            failures.append("\(error)")
        }
        for failure in failures { FileHandle.standardError.write(Data((failure + "\n").utf8)) }
        exit(failures.isEmpty ? 0 : 1)
    }

    private static func shoot(_ content: some View, appearance: NSAppearance.Name, to path: String, size: NSSize = NSSize(width: 900, height: 700)) -> [String] {
        let controller = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.borderless]
        window.appearance = NSAppearance(named: appearance)
        window.setContentSize(size)
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
