import AppKit
import Core
import SwiftUI

#if DEBUG
@MainActor
enum ArchiveRetentionProbe {
    private static let flag = "--archive-retention-probe"
    private static let size = CGSize(width: 640, height: 280)

    static var isRequested: Bool { CommandLine.arguments.contains(flag) }

    static func runAndExit() -> Never {
        NSApplication.shared.setActivationPolicy(.prohibited)
        Task { await run() }
        RunLoop.main.run()
        exit(1)
    }

    private static var directory: String {
        ProbeHarness.text(flag, or: NSTemporaryDirectory() + "unifieddev-archive-retention")
    }

    private static func run() async {
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let cases: [(String, ArchiveRetention, [ArchivedWorkspaceFootprint]?)] = [
            ("off", ArchiveRetention(), []),
            ("limits", ArchiveRetention(days: 30, megabytes: 1_000), [footprint]),
        ]
        var written = 0
        for (name, retention, expired) in cases {
            for scheme in [ColorScheme.light, .dark]
            where await shoot(retention, expired: expired, scheme: scheme, named: "\(name)-\(scheme)") {
                written += 1
            }
        }
        FileHandle.standardError.write(Data("wrote \(written) of \(cases.count * 2)\n".utf8))
        exit(written == cases.count * 2 ? 0 : 1)
    }

    private static var footprint: ArchivedWorkspaceFootprint {
        ArchivedWorkspaceFootprint(
            workspace: Workspace(
                id: WorkspaceID("old"), repoID: RepoID("probe"), name: "Old work", branch: "old", path: "/tmp/old",
                baseBranch: "main"
            ),
            repoName: "probe", sessionCount: 1, messageCount: 12,
            transcriptBytes: 48_000_000, otherBytes: 0, reviewCommentCount: 0, hasNote: false
        )
    }

    private static func shoot(
        _ retention: ArchiveRetention,
        expired: [ArchivedWorkspaceFootprint]?,
        scheme: ColorScheme,
        named name: String
    ) async -> Bool {
        let fields = ArchiveRetentionFields(
            retention: .constant(retention), expired: expired, isEnabled: true
        )
        let host = NSHostingController(rootView: Form { fields }
            .settingsForm()
            .environment(\.colorScheme, scheme)
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
        guard let bitmap = host.view.bitmapImageRepForCachingDisplay(in: host.view.bounds) else { return false }
        host.view.cacheDisplay(in: host.view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return false }
        return (try? data.write(to: URL(filePath: "\(directory)/\(name).png"))) != nil
    }
}
#endif
