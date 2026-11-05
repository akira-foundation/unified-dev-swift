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
                    let frameSelected = CanvasSurface(
                        document: document,
                        worktree: directory,
                        documentPath: model.path,
                        apply: { _ in },
                        initialTool: .select,
                        initialFrameSelection: document.frames.first?.id
                    )
                    .frame(width: 1_200, height: 800)
                    failures += shoot(frameSelected, appearance: appearance, to: "\(directory)/frame-selected-\(name).png", size: NSSize(width: 1_200, height: 800))
                    failures += scrollPanFailures(over: frameSelected, panelPoint: NSPoint(x: 1_050, y: 500))
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
                ("too-large", .tooLargeToSave(82_001_204)),
                ("file-too-large", .fileTooLarge(106_000_000)),
                ("too-large-to-copy", .tooLargeToKeepCopy(82_001_204)),
                ("reloaded", .reloaded(
                    backups: [directory + "/deck.backup-20261103T101500+0000.udcanvas", directory + "/deck.backup-20261103T101640+0000.udcanvas"],
                    typingKeptIn: [directory + "/deck.backup-20261103T101500+0000.udcanvas"]
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
            var stoppedPen = CanvasPenDraft()
            for index in 0..<20_000 where !stoppedPen.hasStopped {
                let turn = Double(index) / 2.3
                stoppedPen.append(CanvasPoint(x: Double(index) * 0.01 + 30 * sin(turn), y: 30 * cos(turn)), tolerance: 1.5)
            }
            if let notice = CanvasStrokeNotice.whileDrawing(stoppedPen) {
                let overlay = Rectangle().fill(Color(nsColor: .underPageBackgroundColor))
                    .overlay(alignment: .top) { CanvasPenLimitNotice(notice: notice) }
                    .frame(width: 900, height: 120)
                failures += shoot(overlay, appearance: .aqua, to: "\(directory)/pen-limit-light.png", size: NSSize(width: 900, height: 120))
                failures += shoot(overlay, appearance: .darkAqua, to: "\(directory)/pen-limit-dark.png", size: NSSize(width: 900, height: 120))
            } else {
                failures.append("the pen did not stop")
            }
            failures += CanvasSavingProbe.run(in: directory)
            failures += CanvasRenderProbe.run(in: directory)
            failures += CanvasCommentsProbe.run(in: directory)
            failures += CanvasExportProbe.run(in: directory)
            failures += CanvasShapesProbe.run(in: directory)
        } catch {
            failures.append("\(error)")
        }
        for failure in failures { FileHandle.standardError.write(Data((failure + "\n").utf8)) }
        exit(failures.isEmpty ? 0 : 1)
    }

    private static func scrollPanFailures(over content: some View, panelPoint: NSPoint) -> [String] {
        let controller = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.borderless]
        window.setContentSize(NSSize(width: 1_200, height: 800))
        window.setFrameOrigin(NSPoint(x: -9_000, y: -9_000))
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        for _ in 0..<5 {
            controller.view.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        }
        guard let pan = firstScrollPan(in: controller.view) else { return ["no scroll pan view in the surface"] }
        let stage = pan.takesScroll(atWindowPoint: NSPoint(x: 200, y: 400))
        let panel = pan.takesScroll(atWindowPoint: panelPoint)
        let outside = pan.takesScroll(atWindowPoint: NSPoint(x: 5_000, y: 400))
        print("MEASURE scroll pan takes: stage \(stage), panel \(panel), outside \(outside)")
        var failures: [String] = []
        if !stage { failures.append("a swipe over the stage is not taken") }
        if panel { failures.append("a swipe over the panel's scroll view is taken") }
        if outside { failures.append("a swipe outside the surface is taken") }
        return failures
    }

    private static func firstScrollPan(in view: NSView) -> CanvasScrollPanView? {
        if let pan = view as? CanvasScrollPanView { return pan }
        return view.subviews.lazy.compactMap { firstScrollPan(in: $0) }.first
    }

    static func shoot(_ content: some View, appearance: NSAppearance.Name, to path: String, size: NSSize = NSSize(width: 900, height: 700)) -> [String] {
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
