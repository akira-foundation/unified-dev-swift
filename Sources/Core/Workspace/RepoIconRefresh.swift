import Foundation

public enum RepoIconRefresh {
    public enum Reason: String, Sendable, Hashable, CaseIterable {
        case neverLooked
        case artworkGone
        case plainerArtwork
    }

    public static func reasonToSearch(
        _ repo: Repo,
        exists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) },
        contents: (String) -> [String] = {
            (try? FileManager.default.contentsOfDirectory(atPath: $0)) ?? []
        }
    ) -> Reason? {
        guard exists((repo.path as NSString).expandingTildeInPath) else { return nil }

        switch repo.iconSource {
        case .undetected:
            return .neverLooked
        case .monogram, .chosen:
            return nil
        case .detected:
            guard let path = repo.iconPath else { return .artworkGone }
            guard exists(path) else { return .artworkGone }
            let directory = (path as NSString).deletingLastPathComponent
            let plainer = RepoIconDetector.hasPlainerName(
                than: (path as NSString).lastPathComponent,
                among: contents(directory)
            )
            return plainer ? .plainerArtwork : nil
        }
    }

    public static func toSearch(
        _ repos: [Repo],
        exists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) },
        contents: (String) -> [String] = {
            (try? FileManager.default.contentsOfDirectory(atPath: $0)) ?? []
        }
    ) -> [Repo] {
        repos.filter { reasonToSearch($0, exists: exists, contents: contents) != nil }
    }
}

public struct RepoIconAnswer: Sendable, Hashable {
    public var iconPath: String?
    public var iconSource: RepoIconSource

    public init(found: RepoIconCandidate?) {
        iconPath = found?.path
        iconSource = found == nil ? .monogram : .detected
    }

    public func apply(to repo: inout Repo) {
        repo.iconPath = iconPath
        repo.iconSource = iconSource
    }

    public func changes(_ repo: Repo) -> Bool {
        repo.iconPath != iconPath || repo.iconSource != iconSource
    }
}
