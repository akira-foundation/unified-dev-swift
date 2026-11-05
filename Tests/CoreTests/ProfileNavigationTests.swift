import Foundation
import Testing
@testable import Core

@Suite("The selection stays inside the active profile")
struct ProfileNavigationTests {
    private let akira = ProfileID("akira")
    private let inUnified = Repo(name: "u", path: "/tmp/u")
    private let inAkira = Repo(name: "a", path: "/tmp/a", profileID: ProfileID("akira"))

    private var repos: [Repo] { [inUnified, inAkira] }

    private func row(_ name: String, _ repo: Repo) -> Workspace {
        Workspace(repoID: repo.id, name: name, branch: name, path: "/tmp/\(name)", baseBranch: "main")
    }

    private func profile(_ id: ProfileID) -> Profile {
        Profile(id: id, name: id.rawValue, folder: id.rawValue, colour: "0A84FF", symbol: "star")
    }

    @Test("every selection naming a workspace or a project has that project's profile")
    func ownerOfEachSelection() {
        let far = row("far", inAkira)
        let selections: [SidebarSelection] = [
            .workspace(far.id),
            .archived(far.id),
            .subagent(far.id, SubagentID("s")),
            .subagentCall(far.id, toolUseID: "t"),
            .crew(far.id, SessionID("c")),
            .draft(inAkira.id),
        ]

        for selection in selections {
            #expect(ProfileNavigation.owner(of: selection, workspaces: [far], repos: repos) == akira)
        }
    }

    @Test("Home and Ask belong to no profile")
    func homeAndAskHaveNoOwner() {
        #expect(ProfileNavigation.owner(of: .home, workspaces: [], repos: repos) == nil)
        #expect(ProfileNavigation.owner(of: .ask, workspaces: [], repos: repos) == nil)
    }

    @Test("opening a workspace of another profile activates that profile first")
    func activatesOtherProfile() {
        let far = row("far", inAkira)

        #expect(ProfileNavigation.activation(
            for: .workspace(far.id), active: .initial, workspaces: [far], repos: repos
        ) == akira)
    }

    @Test("an archived workspace of another profile activates it too")
    func activatesForArchived() {
        var far = row("far", inAkira)
        far.state = .archived

        #expect(ProfileNavigation.activation(
            for: .archived(far.id), active: .initial, workspaces: [far], repos: repos
        ) == akira)
    }

    @Test("a workspace of the active profile activates nothing")
    func sameProfileActivatesNothing() {
        let near = row("near", inUnified)

        #expect(ProfileNavigation.activation(
            for: .workspace(near.id), active: .initial, workspaces: [near], repos: repos
        ) == nil)
    }

    @Test("a workspace whose project cannot be found leaves the active profile alone")
    func orphanActivatesNothing() {
        let orphan = row("orphan", Repo(name: "gone", path: "/tmp/gone"))

        #expect(ProfileNavigation.activation(
            for: .workspace(orphan.id), active: akira, workspaces: [orphan], repos: repos
        ) == nil)
        #expect(ProfileNavigation.activation(
            for: .workspace(.new()), active: akira, workspaces: [orphan], repos: repos
        ) == nil)
    }

    @Test("switching to the current profile or to an unknown one does nothing")
    func maySwitch() {
        let known = [profile(.initial), profile(akira)]

        #expect(ProfileNavigation.maySwitch(to: akira, from: .initial, among: known))
        #expect(!ProfileNavigation.maySwitch(to: .initial, from: .initial, among: known))
        #expect(!ProfileNavigation.maySwitch(to: ProfileID("nobody"), from: .initial, among: known))
    }

    @Test("the landing is the remembered workspace when it is live and still in the profile")
    func landingOnRemembered() {
        let near = row("near", inUnified)
        var memory = ProfileMemory()
        memory.remember(near.id, in: .initial)

        #expect(ProfileNavigation.landing(
            in: .initial, memory: memory, workspaces: [near], repos: repos
        ) == .workspace(near.id))
    }

    @Test("a remembered workspace now outside the profile is not restored")
    func landingRefusesOutsider() {
        let far = row("far", inAkira)
        var memory = ProfileMemory()
        memory.remember(far.id, in: .initial)

        #expect(ProfileNavigation.landing(in: .initial, memory: memory, workspaces: [far], repos: repos) == .home)
    }

    @Test("moving the project under the selection lands the window on what the profile remembers")
    func movedSelectionLands() {
        let moved = row("moved", inAkira)
        let remaining = row("remaining", inUnified)
        var memory = ProfileMemory()
        memory.remember(remaining.id, in: .initial)

        #expect(ProfileNavigation.settled(
            .workspace(moved.id), active: .initial, memory: memory, workspaces: [moved, remaining], repos: repos
        ) == .workspace(remaining.id))
        #expect(ProfileNavigation.settled(
            .crew(moved.id, SessionID("c")), active: .initial, memory: ProfileMemory(), workspaces: [moved], repos: repos
        ) == .home)
        #expect(ProfileNavigation.settled(
            .draft(inAkira.id), active: .initial, memory: ProfileMemory(), workspaces: [], repos: repos
        ) == .home)
    }

    @Test("an archived workspace moved away with its project lands on what the profile remembers")
    func movedArchivedSelectionLands() {
        var archived = row("archived", inAkira)
        archived.state = .archived
        let remaining = row("remaining", inUnified)
        var memory = ProfileMemory()
        memory.remember(remaining.id, in: .initial)

        #expect(ProfileNavigation.settled(
            .archived(archived.id), active: .initial, memory: memory, workspaces: [remaining, archived], repos: repos
        ) == .workspace(remaining.id))
    }

    @Test("a selection inside the active profile, or naming no profile, stays where it is")
    func settledStays() {
        let near = row("near", inUnified)

        #expect(ProfileNavigation.settled(
            .workspace(near.id), active: .initial, memory: ProfileMemory(), workspaces: [near], repos: repos
        ) == nil)
        #expect(ProfileNavigation.settled(
            .ask, active: .initial, memory: ProfileMemory(), workspaces: [], repos: repos
        ) == nil)
        #expect(ProfileNavigation.settled(
            .workspace(.new()), active: .initial, memory: ProfileMemory(), workspaces: [], repos: repos
        ) == nil)
    }

    @Test("Home's narrowing drops the projects the profile does not hold")
    func homeFilterNarrows() {
        let filter = HomeFilter(query: "fix", projects: [inAkira.id, inUnified.id], scope: .running)

        let narrowed = ProfileNavigation.narrowed(filter, to: .initial, repos: repos)

        #expect(narrowed.projects == [inUnified.id])
        #expect(narrowed.query == "fix")
        #expect(narrowed.scope == .running)
    }
}

@Suite("What a profile remembers, across launches")
struct ProfileMemoryRestoreTests {
    @Test("the old key is the memory of unified when nothing newer is stored")
    func legacyBecomesUnified() {
        let memory = ProfileMemory.restored(stored: nil, legacyLastWorkspace: "w1")

        #expect(memory.lastWorkspace == [.initial: WorkspaceID("w1")])
    }

    @Test("once something is stored the old key is not read again")
    func storedWins() throws {
        var kept = ProfileMemory()
        kept.remember(WorkspaceID("w2"), in: ProfileID("akira"))

        let memory = ProfileMemory.restored(stored: try JSONEncoder().encode(kept), legacyLastWorkspace: "w1")

        #expect(memory == kept)
    }

    @Test("nothing stored and no old key is an empty memory, and so is an empty old key")
    func nothingAtAll() {
        #expect(ProfileMemory.restored(stored: nil, legacyLastWorkspace: nil) == ProfileMemory())
        #expect(ProfileMemory.restored(stored: nil, legacyLastWorkspace: "") == ProfileMemory())
    }

    @Test("what cannot be decoded falls back rather than failing")
    func corruptStored() {
        let memory = ProfileMemory.restored(stored: Data("nonsense".utf8), legacyLastWorkspace: "w1")

        #expect(memory.lastWorkspace == [.initial: WorkspaceID("w1")])
    }

    @Test("a deleted profile's entry is dropped and no other")
    func forgetDropsOneEntry() {
        var memory = ProfileMemory()
        memory.remember(WorkspaceID("w1"), in: .initial)
        memory.remember(WorkspaceID("w2"), in: ProfileID("akira"))

        memory.forget(ProfileID("akira"))

        #expect(memory.lastWorkspace == [.initial: WorkspaceID("w1")])
    }
}

@Suite("What the owner reads when a profile refuses")
struct ProfileRefusalWordingTests {
    @Test("the refusals say what to do")
    func sentences() {
        #expect(ProfileDeletionRefused.initial.sentence == "The Unified profile cannot be deleted.")
        #expect(ProfileDeletionRefused.hasProjects(count: 1).sentence
            == "This profile still has 1 project. Move it to another profile first.")
        #expect(ProfileDeletionRefused.hasProjects(count: 3).sentence
            == "This profile still has 3 projects. Move them to another profile first.")
        #expect(ProfileMoveRefused.unknownProfile.sentence == "That profile is no longer in Unified Dev.")
    }

    @Test("adding a folder that another profile holds says which one")
    func alreadyElsewhere() {
        let akira = Profile(id: ProfileID("akira"), name: "Akira", folder: "akira", colour: "0A84FF", symbol: "star")
        let repo = Repo(name: "billing", path: "/tmp/billing", profileID: akira.id)

        #expect(ProfileNotice.alreadyElsewhere(repo, active: .initial, profiles: [akira])
            == "billing is already in the Akira profile. Switch to it, or move the project from there.")
        #expect(ProfileNotice.alreadyElsewhere(repo, active: akira.id, profiles: [akira]) == nil)
        #expect(ProfileNotice.alreadyElsewhere(repo, active: .initial, profiles: []) == nil)
    }
}
