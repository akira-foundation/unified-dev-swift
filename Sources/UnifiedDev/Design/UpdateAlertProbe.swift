import AppKit
import Core

#if DEBUG
@MainActor
enum UpdateAlertProbe {
    private static let flag = "--update-alert-probe"

    static var isRequested: Bool { CommandLine.arguments.contains(flag) }

    static func runAndExit() -> Never {
        NSApplication.shared.setActivationPolicy(.prohibited)
        NSApplication.shared.finishLaunching()
        Task { await run() }
        RunLoop.main.run()
        exit(1)
    }

    private static var directory: String {
        ProbeHarness.text(flag, or: NSTemporaryDirectory() + "unifieddev-update-alert")
    }

    private static func run() async {
        do {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        } catch {
            FileHandle.standardError.write(Data("\(directory): \(error)\n".utf8))
            exit(1)
        }
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
        var written = 0
        var wanted = 0
        for (name, prompt) in prompts() {
            wanted += 1
            if shoot(prompt, named: name) { written += 1 }
        }
        FileHandle.standardError.write(Data("wrote \(written) of \(wanted)\n".utf8))
        exit(written == wanted ? 0 : 1)
    }

    private static func shoot(_ prompt: SoftwareUpdate.Prompt, named name: String) -> Bool {
        let alert = SoftwareUpdater.alert(for: prompt)
        let window = alert.window
        alert.layout()
        window.setFrameOrigin(NSPoint(x: -9_000, y: -9_000))
        window.orderFront(nil)
        window.displayIfNeeded()
        guard let view = window.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            window.orderOut(nil)
            return false
        }
        if view.isFlipped {
            context.cgContext.translateBy(x: 0, y: view.bounds.height)
            context.cgContext.scaleBy(x: 1, y: -1)
        }
        view.layer?.render(in: context.cgContext)
        context.flushGraphics()
        window.orderOut(nil)
        guard let drawn = bitmap.representation(using: .png, properties: [:]) else { return false }
        do {
            try drawn.write(to: URL(filePath: directory + "/" + name + ".png"))
            return true
        } catch {
            FileHandle.standardError.write(Data("\(name): \(error)\n".utf8))
            return false
        }
    }

    private static func prompts() -> [(String, SoftwareUpdate.Prompt)] {
        guard let current = ReleaseVersion("1.0.0"),
              let full = made(notes: notes), let bare = made(notes: "") else { return [] }
        return [
            ("offer", SoftwareUpdate.prompt(for: .install(full, full.assets[0]), currentVersion: current)),
            ("no-notes", SoftwareUpdate.prompt(for: .install(bare, bare.assets[0]), currentVersion: current)),
            ("skipped", SoftwareUpdate.prompt(for: .skipped(full), currentVersion: current)),
            ("missing", SoftwareUpdate.prompt(for: .missingAsset(full), currentVersion: current)),
            ("up-to-date", SoftwareUpdate.prompt(for: .upToDate, currentVersion: current)),
        ]
    }

    private static func made(notes: String) -> GitHubRelease? {
        PreviewScenario.Update(version: "1.1.0", current: "1.0.0", notes: notes).release()
    }

    private static let notes = """
        ### Features

        - *(updates)* the update alert carries the release notes of the version it offers
        - *(updates)* a third button skips a version and stops offering it
        - *(sidebar)* keep every control in the bar, and even the margins
        - *(review)* fold the files you have already read

        ### Bug Fixes

        - *(archive)* an archive no longer reports a worktree it had already removed
        - *(git)* a branch with a slash in its name is quoted before it reaches git
        """
}
#endif
