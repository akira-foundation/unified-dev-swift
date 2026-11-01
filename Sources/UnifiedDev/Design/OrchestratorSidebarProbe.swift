import AppKit
import Core
import SwiftUI

#if DEBUG
@MainActor
enum OrchestratorSidebarProbe {
    private static let flag = "--orchestrator-sidebar-probe"

    static var isRequested: Bool { CommandLine.arguments.contains(flag) }

    static func runAndExit() -> Never {
        NSApplication.shared.setActivationPolicy(.prohibited)
        Task { await run() }
        RunLoop.main.run()
        exit(1)
    }

    private static var directory: String {
        ProbeHarness.text(flag, or: NSTemporaryDirectory() + "unifieddev-orchestrator-sidebar")
    }

    private static let size = CGSize(width: 320, height: 300)

    private static let draftSize = CGSize(width: 720, height: 300)

    private static func run() async {
        do {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        } catch {
            FileHandle.standardError.write(Data("\(directory): \(error)\n".utf8))
            exit(1)
        }
        let app = AppModel()
        var written = 0
        for scheme in [ColorScheme.light, .dark] {
            if await shoot(OrchestratorSidebarGallery(app: app), named: "orchestrator-sidebar", size: size, scheme: scheme) {
                written += 1
            }
            if await shoot(OrchestratorDraftGallery(app: app), named: "orchestrator-draft", size: draftSize, scheme: scheme) {
                written += 1
            }
        }
        FileHandle.standardError.write(Data("wrote \(written) of 4\n".utf8))
        exit(written == 4 ? 0 : 1)
    }

    private static func shoot(
        _ gallery: some View, named prefix: String, size: CGSize, scheme: ColorScheme
    ) async -> Bool {
        let host = NSHostingController(rootView: gallery
            .environment(\.colorScheme, scheme)
            .transaction { $0.disablesAnimations = true }
            .frame(width: size.width, height: size.height))
        host.sizingOptions = []
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentViewController = host
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.layoutSubtreeIfNeeded()
        try? await Task.sleep(for: .milliseconds(400))
        host.view.displayIfNeeded()
        guard let bitmap = host.view.bitmapImageRepForCachingDisplay(in: host.view.bounds),
              let context = NSGraphicsContext(bitmapImageRep: bitmap)
        else { return false }
        if host.view.isFlipped {
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: 1, y: -1)
        }
        host.view.layer?.render(in: context.cgContext)
        context.flushGraphics()
        guard let drawn = bitmap.representation(using: .png, properties: [:]) else { return false }
        let name = "\(prefix)-\(scheme == .dark ? "dark" : "light").png"
        do {
            try drawn.write(to: URL(filePath: directory + "/" + name))
            return true
        } catch {
            FileHandle.standardError.write(Data("\(name): \(error)\n".utf8))
            return false
        }
    }
}
#endif
