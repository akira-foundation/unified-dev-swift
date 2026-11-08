import Testing
@testable import Core

@Suite("A notification names another profile")
struct ProfileNoticeTests {
    private let akira = Profile(id: ProfileID("akira"), name: "Akira", folder: "akira", colour: "0A84FF", symbol: "star")

    @Test("another profile is named")
    func anotherProfile() {
        #expect(ProfileNotice.title("Fix the login", profile: akira, active: .initial) == "Akira: Fix the login")
    }

    @Test("the active profile is not")
    func activeProfile() {
        #expect(ProfileNotice.title("Fix the login", profile: akira, active: akira.id) == "Fix the login")
    }

    @Test("an unknown profile changes nothing")
    func unknownProfile() {
        #expect(ProfileNotice.title("Fix the login", profile: nil, active: .initial) == "Fix the login")
    }

    @Test("a batch from one profile has that profile")
    func batchFromOneProfile() {
        let world = batchWorld()

        #expect(ProfileNotice.profile(
            of: [world.first.id, world.second.id], workspaces: world.all, repos: world.repos
        ) == akira.id)
    }

    @Test("a batch from two profiles has none, because no single name would be true")
    func batchFromTwoProfiles() {
        let world = batchWorld()

        #expect(ProfileNotice.profile(
            of: [world.first.id, world.other.id], workspaces: world.all, repos: world.repos
        ) == nil)
    }

    @Test("a batch naming a workspace nobody can place has none")
    func batchWithUnknownWorkspace() {
        let world = batchWorld()

        #expect(ProfileNotice.profile(
            of: [world.first.id, .new()], workspaces: world.all, repos: world.repos
        ) == nil)
        #expect(ProfileNotice.profile(of: [], workspaces: world.all, repos: world.repos) == nil)
    }

    private struct BatchWorld {
        let first: Workspace
        let second: Workspace
        let other: Workspace
        let repos: [Repo]
        var all: [Workspace] { [first, second, other] }
    }

    private func batchWorld() -> BatchWorld {
        let inAkira = Repo(name: "a", path: "/tmp/a", profileID: akira.id)
        let inUnified = Repo(name: "u", path: "/tmp/u")
        func row(_ name: String, _ repo: Repo) -> Workspace {
            Workspace(repoID: repo.id, name: name, branch: name, path: "/tmp/\(name)", baseBranch: "main")
        }
        return BatchWorld(
            first: row("first", inAkira),
            second: row("second", inAkira),
            other: row("other", inUnified),
            repos: [inAkira, inUnified]
        )
    }
}
