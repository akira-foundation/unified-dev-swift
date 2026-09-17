import SwiftUI
import AppKit
import Core

enum OpenInTarget: Hashable {
    case file(String)
    case folder(String)

    var path: String {
        switch self {
        case .file(let path), .folder(let path): path
        }
    }

    var kind: OpenTargets {
        switch self {
        case .file: .file
        case .folder: .folder
        }
    }

    var enclosingFolder: String {
        switch self {
        case .file(let path): (path as NSString).deletingLastPathComponent
        case .folder(let path): path
        }
    }
}

extension EnvironmentValues {
    @Entry var openInRepoID: RepoID?
}

enum OpenIn {
    static func open(_ path: String, with app: DetectedApp, repo: RepoID?) {
        NSWorkspace.shared.open(
            [URL(fileURLWithPath: path)],
            withApplicationAt: app.url,
            configuration: NSWorkspace.OpenConfiguration()
        )
        OpenInPreferences().record(app.app.bundleID, repo: repo)
    }

    @MainActor
    static func candidates(for target: OpenInTarget, repo: RepoID?) -> [DetectedApp] {
        var apps = InstalledApps.all.filter { $0.app.opens(target.kind) }
        if case .file(let path) = target, let extra = InstalledApps.systemDefault(forFile: path) {
            apps.append(extra)
        }
        let order = EditorCatalog.ordered(
            apps.map(\.app), lastUsed: OpenInPreferences().lastUsed(repo: repo)
        )
        return order.compactMap { app in apps.first { $0.id == app.bundleID } }
    }

    @MainActor
    static func enclosing(for target: OpenInTarget, repo: RepoID?) -> [DetectedApp] {
        guard case .file(let path) = target else { return [] }
        let folder = OpenInTarget.folder((path as NSString).deletingLastPathComponent)
        return candidates(for: folder, repo: repo).filter { !$0.app.opens(.file) }
    }

    @MainActor
    static func preferred(for target: OpenInTarget, repo: RepoID?) -> DetectedApp? {
        candidates(for: target, repo: repo).first
    }
}

struct OpenInItems: View {
    let target: OpenInTarget
    var noun: String?

    @Environment(\.openInRepoID) private var repoID

    var body: some View {
        if OpenIn.preferred(for: target, repo: repoID) == nil {
            Button("Open in Editor") { Reveal.inEditor(target.path, repo: repoID) }
        }

        OpenInMenu(target: target, noun: noun)
    }
}

struct OpenInMenu: View {
    let target: OpenInTarget
    var noun: String?

    @Environment(\.openInRepoID) private var repoID

    var body: some View {
        Menu(title) {
            OpenInAppItems(target: target)
        }
        .disabled(
            OpenIn.candidates(for: target, repo: repoID).isEmpty
                && OpenIn.enclosing(for: target, repo: repoID).isEmpty
        )
    }

    private var title: String {
        if let noun { return "Open \(noun) in" }
        return switch target {
        case .file: "Open File in"
        case .folder: "Open Folder in"
        }
    }
}

struct OpenInAppItems: View {
    let target: OpenInTarget

    @Environment(\.openInRepoID) private var repoID

    var body: some View {
        ForEach(direct) { app in
            item(app, path: target.path)
        }

        if !enclosing.isEmpty {
            Section("Its folder") {
                ForEach(enclosing) { app in
                    item(app, path: target.enclosingFolder)
                }
            }
        }
    }

    private var direct: [DetectedApp] { OpenIn.candidates(for: target, repo: repoID) }

    private var enclosing: [DetectedApp] { OpenIn.enclosing(for: target, repo: repoID) }

    private func item(_ app: DetectedApp, path: String) -> some View {
        Button {
            OpenIn.open(path, with: app, repo: repoID)
        } label: {
            Label {
                Text(app.app.name)
            } icon: {
                Image(nsImage: app.icon)
            }
        }
    }
}
