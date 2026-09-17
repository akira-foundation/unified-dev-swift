import Testing
import Foundation
@testable import Core

@Suite("Looking again for a project's icon")
struct RepoIconRefreshTests {
    private func project(
        _ source: RepoIconSource,
        icon: String? = nil,
        path: String = "/projects/unifieddev"
    ) -> Repo {
        Repo(name: "unifieddev", path: path, iconPath: icon, iconSource: source)
    }

    private let everything: (String) -> Bool = { _ in true }
    private let folderOnly: (String) -> Bool = { $0 == "/projects/unifieddev" }

    @Test("a project nobody has ever looked at is searched")
    func neverLooked() {
        #expect(RepoIconRefresh.reasonToSearch(project(.undetected), exists: everything) == .neverLooked)
    }

    @Test("a project added before Unified Dev looked for icons is searched even with a stale path on it")
    func neverLookedWithAPath() {
        let stale = project(.undetected, icon: "/projects/unifieddev/public/favicon.svg")
        #expect(RepoIconRefresh.reasonToSearch(stale, exists: everything) == .neverLooked)
    }

    @Test("a guess the ranking would no longer make is looked at again, once")
    func plainerArtwork() {
        let badged = project(.detected, icon: "/projects/unifieddev/public/favicon-unread-1.svg")
        let publicFolder = [
            "favicon.svg", "favicon.ico", "favicon-unread-1.svg", "favicon-unread-1.ico",
            "site.webmanifest", "index.php",
        ]
        #expect(
            RepoIconRefresh.reasonToSearch(badged, exists: everything, contents: { _ in publicFolder })
                == .plainerArtwork
        )

        let plain = project(.detected, icon: "/projects/unifieddev/public/favicon.svg")
        #expect(
            RepoIconRefresh.reasonToSearch(plain, exists: everything, contents: { _ in publicFolder })
                == nil
        )

        let onlyDark = project(.detected, icon: "/projects/unifieddev/assets/logo-dark.svg")
        #expect(
            RepoIconRefresh.reasonToSearch(onlyDark, exists: everything, contents: { _ in ["logo-dark.svg"] })
                == nil
        )

        #expect(
            RepoIconRefresh.reasonToSearch(
                project(.detected, icon: "/projects/unifieddev/public/favicon-unread.png"),
                exists: everything,
                contents: { _ in ["favicon-unread.png", "favicon.svg"] }
            ) == nil
        )
    }

    @Test("a file the user chose is never looked past")
    func chosenIsTheLastWord() {
        let chosen = project(.chosen, icon: "/pictures/mark.svg")
        #expect(RepoIconRefresh.reasonToSearch(chosen, exists: everything) == nil)
        #expect(RepoIconRefresh.reasonToSearch(chosen, exists: folderOnly) == nil)
    }

    @Test("initials the user asked for are never replaced with a favicon")
    func monogramIsNeverOverruled() {
        #expect(RepoIconRefresh.reasonToSearch(project(.monogram), exists: everything) == nil)
    }

    @Test("artwork Unified Dev found and can still read is left exactly as it is")
    func detectedAndPresentIsLeftAlone() {
        let detected = project(.detected, icon: "/projects/unifieddev/public/favicon.svg")
        #expect(RepoIconRefresh.reasonToSearch(detected, exists: everything) == nil)
    }

    @Test("artwork that has gone is looked for again")
    func detectedAndGoneIsSearched() {
        let detected = project(.detected, icon: "/projects/unifieddev/public/favicon.svg")
        #expect(RepoIconRefresh.reasonToSearch(detected, exists: folderOnly) == .artworkGone)
    }

    @Test("a project marked as having artwork with no path to it is looked for again")
    func detectedWithNoPathIsSearched() {
        #expect(RepoIconRefresh.reasonToSearch(project(.detected), exists: everything) == .artworkGone)
    }

    @Test("nothing is searched in a folder that is not there", arguments: RepoIconSource.allCases)
    func aMissingFolderIsSkipped(source: RepoIconSource) {
        let away = project(source, icon: "/volumes/work/unifieddev/favicon.svg", path: "/volumes/work/unifieddev")
        #expect(RepoIconRefresh.reasonToSearch(away, exists: { _ in false }) == nil)
    }

    @Test("a path written with a tilde is asked about as the folder it means")
    func homeRelativePathsAreExpanded() {
        let repo = Repo(name: "unifieddev", path: "~/dev/unifieddev", iconSource: .undetected)
        var asked: [String] = []
        let reason = RepoIconRefresh.reasonToSearch(repo) { path in
            asked.append(path)
            return true
        }
        #expect(reason == .neverLooked)
        #expect(asked == [(("~/dev/unifieddev") as NSString).expandingTildeInPath])
        #expect(!asked[0].contains("~"))
    }

    @Test("a sweep takes the two that need it and leaves the two that do not")
    func theListIsFiltered() {
        let repos = [
            project(.undetected, path: "/projects/a"),
            project(.chosen, icon: "/pictures/mark.svg", path: "/projects/b"),
            project(.monogram, path: "/projects/c"),
            project(.detected, icon: "/projects/d/gone.png", path: "/projects/d"),
            project(.detected, icon: "/projects/e/favicon.svg", path: "/projects/e"),
        ]
        let searched = RepoIconRefresh.toSearch(repos) { path in
            !path.hasSuffix("gone.png")
        }
        #expect(searched.map(\.path) == ["/projects/a", "/projects/d"])
    }

    @Test("a search that finds nothing is remembered, and is not searched a second time")
    func nothingFoundIsAnAnswer() {
        var repo = project(.undetected)
        let answer = RepoIconAnswer(found: nil)
        #expect(answer.iconPath == nil)
        #expect(answer.iconSource == .monogram)

        answer.apply(to: &repo)
        #expect(!repo.hasIcon)
        #expect(RepoIconRefresh.reasonToSearch(repo, exists: everything) == nil)
    }

    @Test("a search that finds something stores it as Unified Dev's own guess rather than as a choice")
    func somethingFoundIsStoredAsDetected() {
        var repo = project(.undetected)
        let found = RepoIconCandidate(
            path: "/projects/unifieddev/public/favicon.svg", format: .svg, origin: .favicon, pixels: 0
        )
        let answer = RepoIconAnswer(found: found)
        answer.apply(to: &repo)

        #expect(repo.iconPath == "/projects/unifieddev/public/favicon.svg")
        #expect(repo.iconSource == .detected)
        #expect(repo.hasIcon)
        #expect(RepoIconRefresh.reasonToSearch(repo, exists: everything) == nil)
        #expect(RepoIconRefresh.reasonToSearch(repo, exists: folderOnly) == .artworkGone)
    }

    @Test("an answer only writes when it is different from what the project already has")
    func anUnchangedAnswerWritesNothing() {
        let found = RepoIconCandidate(
            path: "/projects/unifieddev/public/favicon.svg", format: .svg, origin: .favicon, pixels: 0
        )
        let same = project(.detected, icon: "/projects/unifieddev/public/favicon.svg")
        #expect(!RepoIconAnswer(found: found).changes(same))
        #expect(RepoIconAnswer(found: nil).changes(same))
        #expect(RepoIconAnswer(found: found).changes(project(.undetected)))
    }

    @Test("applying an answer changes nothing else about the project")
    func applyingTouchesOnlyTheIcon() {
        var repo = Repo(
            id: RepoID("repo-1"),
            name: "Unified Dev",
            path: "/projects/unifieddev",
            defaultBranch: "trunk",
            accent: "FF3B30",
            sortOrder: 4,
            collapsed: true,
            iconSource: .undetected
        )
        let before = repo
        RepoIconAnswer(found: nil).apply(to: &repo)

        #expect(repo.id == before.id)
        #expect(repo.name == before.name)
        #expect(repo.path == before.path)
        #expect(repo.defaultBranch == before.defaultBranch)
        #expect(repo.accent == before.accent)
        #expect(repo.sortOrder == before.sortOrder)
        #expect(repo.collapsed == before.collapsed)
        #expect(repo.createdAt == before.createdAt)
    }
}
