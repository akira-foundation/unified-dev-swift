import AppKit
import Foundation
import Core

@MainActor
enum DeepLink {
    static let schemes: Set<String> = {
        let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]
        let registered = (types ?? [])
            .compactMap { $0["CFBundleURLSchemes"] as? [String] }
            .flatMap { $0 }
            .map { $0.lowercased() }

        return registered.isEmpty ? ["unifieddev"] : Set(registered)
    }()

    private static var lastHandled: (url: URL, at: Date)?

    static func open(_ url: URL, in app: AppModel) {
        if let last = lastHandled, last.url == url, Date.now.timeIntervalSince(last.at) < 2 {
            return
        }
        lastHandled = (url, .now)

        guard let scheme = url.scheme?.lowercased(), Self.schemes.contains(scheme),
              let values = values(from: url),
              let prompt = values["prompt"]?.removingPercentEncoding,
              let path = values["path"]?.removingPercentEncoding,
              !prompt.isEmpty,
              !path.isEmpty else {
            app.alert = AppAlert(
                title: "Could not open the Unified Dev link",
                message: "The link must include a prompt and project path."
            )
            return
        }

        guard let repo = BridgeProjectLookup.project(atPath: path, in: app.repos) else {
            app.alert = AppAlert(
                title: "Project not found",
                message: "The path in this link is not one of Unified Dev's projects: \(path)"
            )
            return
        }

        Task { await app.createWorkspace(in: repo, prompt: prompt) }
    }

    private static func values(from url: URL) -> [String: String]? {
        let absolute = url.absoluteString
        guard let separator = absolute.range(of: "://") else { return nil }
        var payload = String(absolute[separator.upperBound...])
        if payload.hasPrefix("?") { payload.removeFirst() }

        var values: [String: String] = [:]
        for pair in payload.split(separator: "&", omittingEmptySubsequences: true) {
            let pieces = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pieces.count == 2 else { continue }
            values[String(pieces[0])] = String(pieces[1]).replacing("+", with: " ")
        }
        return values
    }
}
