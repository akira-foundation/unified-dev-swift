import Foundation
import Testing
@testable import Core

@Suite("Search panel profiles")
struct SearchPanelProfilesTests {
    private func profile(_ name: String, _ order: Int) -> Profile {
        Profile(
            id: ProfileID(name.lowercased()),
            name: name,
            folder: name.lowercased(),
            colour: "4C8DF6",
            symbol: "building.2",
            sortOrder: order,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    private let repo = Repo(id: RepoID("repo"), name: "unifieddev", path: "/tmp/repo")

    private func workspace(_ name: String) -> Workspace {
        Workspace(
            id: WorkspaceID(name),
            repoID: repo.id,
            name: name,
            branch: "feature/x",
            path: "/tmp/\(name)",
            baseBranch: "main",
            state: .active,
            lastActivityAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private func build(
        _ query: String,
        workspaces: [Workspace] = [],
        scope: HomeScope = .all,
        profiles: [Profile],
        active: ProfileID = .initial
    ) -> SearchPanelListing {
        SearchPanelResults.build(
            query: query,
            repos: [repo],
            workspaces: workspaces,
            archived: [],
            transcripts: [],
            scope: scope,
            commands: [],
            profiles: profiles,
            activeProfile: active
        )
    }

    private var unified: Profile { profile("Unified", 0) }
    private var foundation: Profile { profile("Foundation", 1) }
    private var folio: Profile { profile("Folio", 2) }

    @Test("a profile is found by the start of its name, under its own heading")
    func foundByName() {
        let listing = build("fo", profiles: [unified, foundation])
        let section = listing.sections.first { $0.id == "profiles" }
        #expect(section?.title == "Profiles")
        #expect(section?.rows.map(\.id) == ["profile:foundation"])
        guard case .profile(let hit) = section?.rows.first else {
            Issue.record("expected a profile row")
            return
        }
        #expect(hit.highlights == [0, 1])
    }

    @Test("the active profile is left out, because there is nothing to switch to")
    func theActiveProfileIsNotOffered() {
        let listing = build("nif", profiles: [unified, foundation], active: .initial)
        #expect(!listing.sections.contains { $0.id == "profiles" })
        #expect(listing.nothing != nil)
    }

    @Test("profiles appear under Everything and under no other scope")
    func onlyUnderEverything() {
        for scope in [HomeScope.workspaces, .transcripts, .archived] {
            #expect(!build("fo", scope: scope, profiles: [foundation]).sections.contains { $0.id == "profiles" })
        }
    }

    @Test("one letter is too little to offer a profile, as with commands")
    func oneLetterIsNotEnough() {
        #expect(build("f", profiles: [foundation]).isEmpty)
    }

    @Test("the better match comes first, and a tie keeps the position in the switcher")
    func relevanceThenPosition() {
        let hits = SearchPanelProfiles.hits("fo", scope: .all, in: [unified, foundation, folio], active: .initial)
        #expect(hits.map(\.profile.name) == ["Folio", "Foundation"])

        let twins = [profile("Aa one", 0), profile("Aa two", 1)]
        let tied = SearchPanelProfiles.hits("aa", scope: .all, in: twins, active: ProfileID("none"))
        #expect(tied.map(\.profile.name) == ["Aa one", "Aa two"])
    }

    @Test("the section leads the workspaces only when its best match is at least as good")
    func theSectionFollowsRelevance() {
        let leading = build("fo", workspaces: [workspace("a long workspace with an f and an o")], profiles: [foundation])
        #expect(leading.sections.map(\.id) == ["profiles", "workspaces"])

        let trailing = build("fo", workspaces: [workspace("Fo")], profiles: [foundation])
        #expect(trailing.sections.map(\.id) == ["workspaces", "profiles"])
    }

    @Test("a profile counts towards Everything, and alone it is still a result")
    func counted() {
        let listing = build("fo", profiles: [foundation])
        #expect(listing.counts.count(of: .all, searching: true) == 1)
        #expect(listing.counts.count(of: .workspaces, searching: true) == 0)
        #expect(listing.summary == "1 result")
        #expect(listing.nothing == nil)
    }

    @Test("a profile row cannot be pushed into")
    func notDrillable() {
        #expect(build("fo", profiles: [foundation]).rows.first?.drillable == nil)
    }

    @Test("the row names the shortcut of its position in the switcher, and none beyond nine")
    func theShortcut() {
        let hits = SearchPanelProfiles.hits("fo", scope: .all, in: [unified, foundation], active: .initial)
        #expect(hits.first?.keyText == "\u{2303}\u{2318}2")

        let many = (0..<9).map { profile("Other \($0)", $0) } + [foundation]
        let last = SearchPanelProfiles.hits("fo", scope: .all, in: many, active: .initial)
        #expect(last.first?.keyText == nil)
    }
}
