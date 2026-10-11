import AppKit
import Core

@MainActor
enum ArchivedColumnsProbe {
    private static let harness = ProbeHarness(subject: "archived-columns")
    static var isRequested: Bool { harness.isRequested }

    static func schedule() { Task { @MainActor in await run() } }

    private static var drawsSidebar: Bool {
        UnifiedDevApp.widths.sidebarMaximum(
            sharing: ProbeHarness.points("--window-available-width", or: .greatestFiniteMagnitude),
            withInspector: false
        ) != nil
    }

    private struct Drawn {
        var columns: [Column]
        var identifiers: Set<String>

        struct Column {
            var collapsed: Bool
            var width: CGFloat
            var onScreen: Bool
        }

        var sidebar: Column? { columns.count == 3 ? columns[0] : nil }
        var centre: Column? { columns.count == 3 ? columns[1] : nil }
        var inspector: Column? { columns.count == 3 ? columns[2] : nil }

        var showsSomething: Bool { columns.contains { $0.onScreen } }

        var json: JSONValue {
            .object([
                "columns": .array(columns.map {
                    .object([
                        "collapsed": .bool($0.collapsed),
                        "width": .number(Double($0.width)),
                        "onScreen": .bool($0.onScreen),
                    ])
                }),
                "archiveView": .bool(identifiers.contains(ArchivedWorkspaceView.identifier)),
            ])
        }
    }

    private struct Fixture {
        var root: URL
        var repo: Repo
        var archived: Workspace
        var live: Workspace
    }

    private static func run() async {
        guard PreviewIdentity.isPreview(bundleIdentifier: Bundle.main.bundleIdentifier) else {
            harness.fail("requires a worktree preview, not \(Bundle.main.bundleIdentifier ?? "nothing")")
        }
        let (window, content) = await harness.window()
        guard let app = ProbeHarness.appModel, let store = app.store else { harness.fail("no app store") }
        for _ in 0..<200 where !app.isLoaded { try? await Task.sleep(for: .milliseconds(100)) }

        var failures: [String] = []
        var report: [String: JSONValue] = [:]
        var fixture: Fixture?

        do {
            let built = try await makeFixture(app: app, store: store)
            fixture = built
            guard let archived = await app.archivedWorkspaces().first(where: { $0.id == built.archived.id })
            else { harness.fail("the fixture workspace did not archive") }

            func look(_ name: String) async -> Drawn {
                try? await Task.sleep(for: .milliseconds(1_500))
                window.layoutIfNeeded()
                content.layoutSubtreeIfNeeded()
                try? await Task.sleep(for: .milliseconds(800))
                let drawn = measure(window)
                report[name] = drawn.json
                return drawn
            }

            func expect(_ drawn: Drawn, _ name: String, sidebar: Bool?, archiveView: Bool) {
                guard drawn.columns.count == 3 else {
                    failures.append("\(name) drew \(drawn.columns.count) columns instead of three")
                    return
                }
                if !drawn.showsSomething { failures.append("\(name) left the window with nothing drawn") }
                if drawn.centre?.onScreen != true { failures.append("\(name) folded the centre column away") }
                if let sidebar, drawn.sidebar?.onScreen != sidebar {
                    failures.append("\(name) drew the sidebar as \(drawn.sidebar?.onScreen == true), wanted \(sidebar)")
                }
                if archiveView, !drawn.identifiers.contains(ArchivedWorkspaceView.identifier) {
                    failures.append("\(name) drew no archive view")
                }
            }

            let sidebar = drawsSidebar
            app.selection = .workspace(built.live.id)
            expect(await look("live"), "a live workspace", sidebar: sidebar, archiveView: false)

            app.openArchived(archived)
            expect(await look("archived"), "an archived workspace", sidebar: sidebar, archiveView: true)

            app.isSidebarHidden = true
            var blankSamples = 0
            var centrelessSamples = 0
            var samples = 0
            for _ in 0..<60 {
                try? await Task.sleep(for: .milliseconds(50))
                window.layoutIfNeeded()
                let sample = measure(window)
                samples += 1
                if !sample.showsSomething { blankSamples += 1 }
                if sample.centre?.onScreen != true { centrelessSamples += 1 }
            }
            report["whileHiding"] = .object([
                "samples": .integer(samples),
                "blank": .integer(blankSamples),
                "withoutCentre": .integer(centrelessSamples),
            ])
            if blankSamples > 0 {
                failures.append("hiding the sidebar left the window blank for \(blankSamples) of \(samples) samples")
            }
            if centrelessSamples > 0 {
                failures.append("hiding the sidebar took the centre column away for \(centrelessSamples) of \(samples) samples")
            }
            expect(
                await look("archived-while-hiding"),
                "an archived workspace with the sidebar hidden", sidebar: false, archiveView: true
            )

            app.selection = .home
            expect(await look("home"), "Home with the sidebar hidden", sidebar: false, archiveView: false)

            app.selection = .workspace(built.live.id)
            expect(
                await look("live-again"), "a live workspace with the sidebar hidden",
                sidebar: false, archiveView: false
            )

            app.isSidebarHidden = false
            app.openArchived(archived)
            expect(
                await look("archived-again"), "an archived workspace after the sidebar came back",
                sidebar: sidebar, archiveView: true
            )
        } catch {
            failures.append("the fixture could not be built: \(error)")
        }

        app.selection = .home
        if let fixture {
            await app.removeRepository(fixture.repo)
            try? FileManager.default.removeItem(at: fixture.root)
        }

        report["passed"] = .bool(failures.isEmpty)
        report["failures"] = .strings(failures)
        harness.write(.object(report), echo: true)
        exit(failures.isEmpty ? 0 : 1)
    }

    private static func makeFixture(app: AppModel, store: Store) async throws -> Fixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("unifieddev-archived-columns-\(UUID().uuidString)")
        let repoPath = root.appendingPathComponent("atlas").path
        try FileManager.default.createDirectory(atPath: repoPath, withIntermediateDirectories: true)
        try await Shell.check("git", ["init", "-q", "-b", "main"], cwd: repoPath)
        try await Shell.check("git", Self.author + ["commit", "--allow-empty", "-qm", "Draw the first map"], cwd: repoPath)

        let repo = try await store.upsert(Repo(name: "Archived columns probe", path: repoPath))
        let archived = try await worktree(
            "Test run", branch: "test-run", in: repo, at: root, store: store
        )
        let live = try await worktree(
            "Dinghy", branch: "dinghy", in: repo, at: root, store: store
        )
        let session = try await store.upsert(Session(workspaceID: archived.id, title: "Only chat"))
        _ = try await store.appendNext(
            sessionID: session.id, kind: .user,
            payload: try line("What happens when I click this?", role: "user")
        )
        _ = try await store.appendNext(
            sessionID: session.id, kind: .assistantText,
            payload: try line("The archive card, the button and this transcript.", role: "assistant")
        )
        await app.reload()

        await app.archive(archived, deleteBranch: false)
        if let request = app.pendingArchive { await app.confirmArchive(request) }
        for _ in 0..<200 where try await store.workspace(id: archived.id)?.state != .archived {
            try? await Task.sleep(for: .milliseconds(100))
        }
        await app.reload()
        return Fixture(root: root, repo: repo, archived: archived, live: live)
    }

    private static func worktree(
        _ name: String, branch: String, in repo: Repo, at root: URL, store: Store
    ) async throws -> Workspace {
        let path = root.appendingPathComponent(branch).path
        try await Shell.check("git", ["worktree", "add", "-qb", branch, path], cwd: repo.path)
        return try await store.upsert(Workspace(
            repoID: repo.id, name: name, branch: branch, path: path, baseBranch: "main"
        ))
    }

    private static func line(_ text: String, role: String) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "type": role,
                "message": ["role": role, "content": [["type": "text", "text": text]]],
            ],
            options: [.sortedKeys]
        )
    }

    private static let author = [
        "-c", "user.name=Archived Columns Probe",
        "-c", "user.email=probe@unifieddev.invalid",
        "-c", "commit.gpgsign=false",
    ]

    private static func measure(_ window: NSWindow) -> Drawn {
        let identifiers = identifiers(in: window.contentView)
        guard let root = window.contentView, let split = splitView(under: root) else {
            return Drawn(columns: [], identifiers: identifiers)
        }
        let controller = split.delegate as? NSSplitViewController
        let columns = (controller?.splitViewItems ?? []).map { item in
            let view = item.viewController.view
            return Drawn.Column(
                collapsed: item.isCollapsed,
                width: view.frame.width,
                onScreen: !item.isCollapsed && view.frame.width > 1 && view.window != nil
            )
        }
        return Drawn(columns: columns, identifiers: identifiers)
    }

    private static func splitView(under view: NSView) -> NSSplitView? {
        if let split = view as? NSSplitView, split.delegate is NSSplitViewController { return split }
        for subview in view.subviews {
            if let found = splitView(under: subview) { return found }
        }
        return nil
    }

    private static func identifiers(in root: Any?) -> Set<String> {
        guard let element = root as? any NSAccessibilityProtocol else { return [] }
        var result = Set<String>()
        if let identifier = element.accessibilityIdentifier() { result.insert(identifier) }
        for child in element.accessibilityChildren() ?? [] {
            result.formUnion(identifiers(in: child))
        }
        return result
    }
}
