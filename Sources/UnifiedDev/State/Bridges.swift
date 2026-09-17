import Foundation
import AppKit
import Core

enum GitHubBridge {
    static func readPullRequest(for workspace: Workspace, maxAge: Duration = .zero) async -> PullRequestRead {
        let availability = await GitHubAvailability.shared.check()
        if availability == .notInstalled {
            return .unavailable(GitHubReadFailure(reason: .unavailable, message: "Install the GitHub CLI to refresh pull requests."))
        }
        guard availability == .ready else {
            return .unavailable(GitHubReadFailure(reason: .authentication, message: "Connect GitHub to refresh pull requests."))
        }
        return await GitHub.readPullRequest(for: workspace, maxAge: maxAge)
    }

    static func pullRequest(
        for workspace: Workspace, maxAge: Duration = .zero
    ) async -> PullRequest? {
        guard case .current(let pullRequest) = await readPullRequest(for: workspace, maxAge: maxAge) else { return nil }
        return pullRequest
    }

    static func checks(for workspace: Workspace) async -> [CheckRun]? {
        do {
            return try await GitHub.checks(for: workspace)
        } catch {
            return []
        }
    }

    static func open(_ url: String) {
        guard let target = URL(string: url) else { return }
        NSWorkspace.shared.open(target)
    }
}

enum Reveal {
    static func inFinder(_ path: String) {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: (path as NSString).deletingLastPathComponent)
    }

    @MainActor
    static func inEditor(_ path: String, repo: RepoID? = nil) {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        let target: OpenInTarget = isDirectory.boolValue ? .folder(path) : .file(path)
        if let app = OpenIn.preferred(for: target, repo: repo) {
            OpenIn.open(path, with: app, repo: repo)
            return
        }

        let url = URL(fileURLWithPath: path)
        for bundleID in ["com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92", "com.apple.dt.Xcode"] {
            if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                NSWorkspace.shared.open(
                    [url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration()
                )
                return
            }
        }
        NSWorkspace.shared.open(url)
    }
}
