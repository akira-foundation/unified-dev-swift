import AppKit
import Core
import SwiftUI

#if DEBUG
@MainActor
enum ReviewFoldProbe {
    static func runAndExit(directory: String) async -> Never {
        var failures: [String] = []
        var checks = 0
        func check(_ condition: Bool, _ message: String) {
            checks += 1
            if !condition { failures.append(message) }
        }
        await run(directory: directory, check: check)
        let result: JSONValue = .object([
            "checks": .integer(checks), "passed": .bool(failures.isEmpty), "failures": .strings(failures),
        ])
        if let data = try? JSONEncoder().encode(result) { FileHandle.standardOutput.write(data) }
        exit(failures.isEmpty ? 0 : 1)
    }

    private static func run(directory: String, check: (Bool, String) -> Void) async {
        setenv(Store.databaseOverride, directory + "/fold.sqlite", 1)
        let app = AppModel()
        await app.bootstrap()
        guard let store = app.store else {
            check(false, "the fold probe could not open its own database")
            return
        }
        let model: WorkspaceModel
        do {
            model = try await seed(directory: directory, app: app, store: store)
        } catch {
            check(false, "fold fixture failed: \(error)")
            return
        }
        await model.refreshChanges()
        await model.reloadViewedFiles()
        check(model.reviewFiles.count == 4, "fold fixture loaded \(model.reviewFiles.count) files, expected four")
        guard let readme = model.reviewFiles.first(where: { $0.path == "README.md" }),
              let checkout = model.reviewFiles.first(where: { $0.path == "Sources/Checkout.swift" }) else {
            check(false, "fold fixture is missing the files the checks are about")
            return
        }

        model.selectedFilePath = readme.path
        FileReview.setShowsAllFiles(true, in: model)
        let host = NSHostingView(rootView: Fixture(model: model))
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1120, height: 760),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = host
        await settle(window)
        save(host, at: directory + "/fold-expanded.png")
        let expanded = documentHeight(in: host)
        check(expanded > 0, "the review drew no document to measure")

        await model.setViewed(true, file: readme)
        await settle(window) { ReviewFoldReport.collapsed.contains(readme.path) }
        check(model.isViewed(readme), "the tick did not reach the model, so nothing below means anything")
        save(host, at: directory + "/fold-viewed.png")
        let folded = documentHeight(in: host)
        check(folded < expanded - 400,
              "ticking a file left the document at \(folded), from \(expanded): the diff did not fold")
        check(!drawn(in: host).contains(readme.path),
              "ticking a file left its diff drawn: \(drawn(in: host))")

        await checkSecondTickAndResize(model: model, first: readme, second: checkout,
                                       host: host, window: window, check: check)
        await checkRefreshKeepsFolding(model: model, host: host, window: window, check: check)
        await checkEveryTick(model: model, host: host, window: window, directory: directory, check: check)

        check(!window.isVisible && !window.isKeyWindow, "fold probe activated its window")
        window.contentView = nil
        withExtendedLifetime(app) {}
    }

    private static func checkSecondTickAndResize(
        model: WorkspaceModel, first: ChangedFile, second: ChangedFile, host: NSView, window: NSWindow,
        check: (Bool, String) -> Void
    ) async {
        await model.setViewed(true, file: second)
        await settle(window) { ReviewFoldReport.collapsed.contains(second.path) }
        check(ReviewFoldReport.collapsed.contains(second.path),
              "ticking a second file did not fold it as well: \(ReviewFoldReport.collapsed)")
        check(ReviewFoldReport.collapsed.contains(first.path),
              "ticking a second file unfolded the first: \(ReviewFoldReport.collapsed)")

        let foldedPaths = ReviewFoldReport.collapsed
        window.setContentSize(NSSize(width: 980, height: 760))
        await settle(window)
        window.setContentSize(NSSize(width: 1120, height: 760))
        await settle(window)
        check(ReviewFoldReport.collapsed == foldedPaths,
              "a resize moved the folding: \(ReviewFoldReport.collapsed), from \(foldedPaths)")
        check(drawn(in: host).isDisjoint(with: foldedPaths),
              "a resize redrew a folded diff: \(drawn(in: host).intersection(foldedPaths))")
    }

    private static func checkRefreshKeepsFolding(
        model: WorkspaceModel, host: NSView, window: NSWindow, check: (Bool, String) -> Void
    ) async {
        let foldedPaths = ReviewFoldReport.collapsed
        await model.refreshChanges()
        await settle(window)
        check(ReviewFoldReport.collapsed == foldedPaths,
              "a changes refresh moved the folding: \(ReviewFoldReport.collapsed), from \(foldedPaths)")
        check(drawn(in: host).isDisjoint(with: foldedPaths),
              "a changes refresh redrew a folded diff: \(drawn(in: host).intersection(foldedPaths))")
    }

    private static func checkEveryTick(
        model: WorkspaceModel, host: NSView, window: NSWindow, directory: String,
        check: (Bool, String) -> Void
    ) async {
        let every = Set(model.reviewFiles.map(\.path))
        for file in model.reviewFiles { await model.setViewed(true, file: file) }
        await settle(window) { ReviewFoldReport.collapsed == every }
        save(host, at: directory + "/fold-all-viewed.png")
        let allFolded = documentHeight(in: host)
        check(allFolded < InspectorLayout.reviewHeaderHeight * CGFloat(model.reviewFiles.count) + 4,
              "four ticked files came to \(allFolded), which is more than four header rows")

        for file in model.reviewFiles { await model.setViewed(false, file: file) }
        await settle(window) { ReviewFoldReport.collapsed.isEmpty }
        save(host, at: directory + "/fold-unviewed.png")
        let reopened = documentHeight(in: host)
        check(reopened > allFolded + 400,
              "taking every tick off left the document at \(reopened), barely over the folded \(allFolded)")
    }

    private static let bodyMarkers = [
        "README.md": "of the readme, rewritten",
        "Docs/notes.md": "- Three.",
        "Config/features.json": "free_shipping",
        "Sources/Checkout.swift": "let checkoutLine",
    ]

    private static func drawn(in view: NSView) -> Set<String> {
        let bodies = textViews(in: view).map(\.string)
        return Set(bodyMarkers.filter { _, marker in bodies.contains { $0.contains(marker) } }.keys)
    }

    private static func textViews(in view: NSView) -> [WrappedCodeText.TextView] {
        if let text = view as? WrappedCodeText.TextView { return [text] }
        return view.subviews.flatMap { textViews(in: $0) }
    }

    private static func documentHeight(in view: NSView) -> CGFloat {
        scrollView(in: view)?.documentView?.bounds.height ?? 0
    }

    private static func scrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        return view.subviews.lazy.compactMap { scrollView(in: $0) }.first
    }

    private static func save(_ host: NSView, at path: String) {
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: URL(fileURLWithPath: path))
    }

    private static func settle(_ window: NSWindow) async {
        for _ in 0..<30 {
            window.contentView?.layoutSubtreeIfNeeded()
            try? await Task.sleep(for: .milliseconds(30))
        }
    }

    private static func settle(_ window: NSWindow, until done: () -> Bool) async {
        await settle(window)
        let deadline = Date.now.addingTimeInterval(5)
        while !done(), Date.now < deadline { await settle(window) }
    }

    private static func seed(directory: String, app: AppModel, store: Store) async throws -> WorkspaceModel {
        let origin = directory + "/fold-repo"
        let worktree = directory + "/fold"
        try FileManager.default.createDirectory(atPath: origin, withIntermediateDirectories: true)
        func git(_ arguments: [String], cwd: String = origin) async throws {
            try await Shell.check("git", ["-c", "commit.gpgsign=false", "-c", "user.name=Fold Probe",
                                          "-c", "user.email=fold@example.test"] + arguments, cwd: cwd)
        }
        func write(_ name: String, _ body: String, in root: String) throws {
            let path = root + "/" + name
            try FileManager.default.createDirectory(
                atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true
            )
            try body.write(toFile: path, atomically: true, encoding: .utf8)
        }
        try await git(["init", "-q", "-b", "main"])
        try write("README.md", "# Checkout\n\nShipping costs 4.95 for every order.\n", in: origin)
        try write("Docs/notes.md", "# Notes\n\n- One.\n", in: origin)
        try write("Config/features.json", "{\"free_shipping\": false}\n", in: origin)
        try write("Sources/Checkout.swift", "struct Checkout {\n    var shipping: Decimal { 4.95 }\n}\n", in: origin)
        try await git(["add", "."])
        try await git(["commit", "-qm", "Baseline"])
        try await git(["worktree", "add", "-qb", "fold", worktree])
        try write("README.md", (0..<40).map { "Line \($0) of the readme, rewritten.\n" }.joined(), in: worktree)
        try write("Docs/notes.md", "# Notes\n\n- One.\n- Two.\n- Three.\n", in: worktree)
        try write("Config/features.json", "{\"free_shipping\": true, \"threshold\": 50}\n", in: worktree)
        try write("Sources/Checkout.swift", (0..<40).map { "let checkoutLine\($0) = \($0)\n" }.joined(), in: worktree)

        let repo = try await store.upsert(Repo(name: "Fold probe", path: origin))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "Fold", branch: "fold", path: worktree, baseBranch: "main"
        ))
        await app.reload()
        return WorkspaceModel(workspace: workspace, app: app)
    }

    private struct Fixture: View {
        let model: WorkspaceModel

        var body: some View {
            if let tab = CenterTabStore.shared.review(for: model.workspace.id) {
                AllFilesReviewView(model: model, selectedPath: tab.path,
                                   navigationRevision: tab.reviewNavigationRevision)
            }
        }
    }
}
#endif
