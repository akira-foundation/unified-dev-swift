import Foundation

public enum WorkSuggestionTarget {
    public static func read(
        _ raw: String?, callerProject: RepoID?, projects: [Repo]
    ) -> Result<WorkSuggestion.Target, WorkSuggestTrouble> {
        guard let given = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !given.isEmpty else {
            return callerProject == nil ? .failure(.needsProject) : .success(.sameProject)
        }
        guard !HiddenText.hasControls(given) else { return .failure(.controlInProject) }

        switch BridgeProjectLookup.find(given, in: projects) {
        case .found(let repo): return .success(target(of: repo, callerProject: callerProject))
        case .ambiguous(let matches): return .failure(.ambiguousProject(given: given, paths: matches.map(\.path)))
        case .unknown: break
        }

        if given.hasPrefix("/") || given.hasPrefix("~") {
            let path = FolderPath.normalize((given as NSString).expandingTildeInPath)
            if let repo = BridgeProjectLookup.project(atPath: path, in: projects) {
                return .success(target(of: repo, callerProject: callerProject))
            }
            return .success(.folder(path))
        }

        if let slug = remoteSlug(given) { return .success(.remote(slug)) }

        return .failure(.unknownProject(given: given, known: projects.map(\.name)))
    }

    public static func remoteSlug(_ given: String) -> String? {
        var text = given.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["https://github.com/", "http://github.com/", "git@github.com:", "github.com/"]
        where text.lowercased().hasPrefix(prefix) {
            text = String(text.dropFirst(prefix.count))
        }
        if text.hasSuffix("/") { text = String(text.dropLast()) }
        if text.hasSuffix(".git") { text = String(text.dropLast(4)) }
        let parts = text.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2, parts.allSatisfy(isSlugPart) else { return nil }
        return text
    }

    public static func gitHubSlug(ofRemote url: String) -> String? {
        guard let specifier = GitHub.repositorySpecifier(url.trimmingCharacters(in: .whitespacesAndNewlines)),
              specifier.hasPrefix("github.com/")
        else { return nil }
        return remoteSlug(specifier)
    }

    public static func resolving(
        _ target: WorkSuggestion.Target, callerProject: RepoID?, projects: [Repo]
    ) async -> WorkSuggestion.Target {
        guard case .remote(let slug) = target else { return target }
        for repo in projects {
            guard let url = await Git.remoteURL("origin", in: repo.path),
                  let cloned = gitHubSlug(ofRemote: url),
                  cloned.caseInsensitiveCompare(slug) == .orderedSame
            else { continue }
            return self.target(of: repo, callerProject: callerProject)
        }
        return target
    }

    private static func target(of repo: Repo, callerProject: RepoID?) -> WorkSuggestion.Target {
        repo.id == callerProject ? .sameProject : .project(repo.id)
    }

    private static func isSlugPart(_ part: Substring) -> Bool {
        !part.isEmpty && part != "." && part != ".." && part.unicodeScalars.allSatisfy {
            $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" || $0 == ".")
        }
    }
}
