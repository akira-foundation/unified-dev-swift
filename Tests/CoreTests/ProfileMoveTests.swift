import Foundation
import Testing
@testable import Core

@Suite("Moving a project to another profile")
struct ProfileMoveTests {
    private func profile(_ id: String) -> Profile {
        Profile(id: ProfileID(id), name: id, folder: id, colour: Accent.all[0], symbol: "leaf")
    }

    private func repo(_ name: String, in owner: String, hidden: Bool = false) -> Repo {
        Repo(name: name, path: "/tmp/\(name)", hidden: hidden, profileID: ProfileID(owner))
    }

    @Test("the targets are the other profiles, in their own order")
    func otherProfiles() {
        let targets = ProfileMove.targets(
            for: repo("site", in: "b"), among: [profile("a"), profile("b"), profile("c")]
        )
        #expect(targets.map(\.id.rawValue) == ["a", "c"])
    }

    @Test("with a single profile there is nowhere to move to")
    func singleProfile() {
        #expect(ProfileMove.targets(for: repo("site", in: "a"), among: [profile("a")]).isEmpty)
    }

    @Test("a single profile hides the move even for a project that names another")
    func singleProfileUnknownOwner() {
        #expect(ProfileMove.targets(for: repo("site", in: "gone"), among: [profile("a")]).isEmpty)
    }

    @Test("Home's menu offers nothing to move with a single profile")
    func homeMenuSingleProfile() {
        let menu = HomeProjectMenu([repo("site", in: "a")], profiles: [profile("a")])
        #expect(menu.moves.isEmpty)
    }

    @Test("Home's menu offers every project with the profiles it could go to")
    func homeMenuMoves() {
        let menu = HomeProjectMenu(
            [repo("zeta", in: "a"), repo("alpha", in: "a"), repo("muted", in: "a", hidden: true)],
            profiles: [profile("a"), profile("b")]
        )
        #expect(menu.moves.map(\.repo.name) == ["alpha", "zeta", "muted"])
        #expect(menu.moves.allSatisfy { $0.targets.map(\.id.rawValue) == ["b"] })
    }

    @Test("Home's menu without profiles still sorts its projects")
    func homeMenuWithoutProfiles() {
        let menu = HomeProjectMenu([repo("site", in: "a")])
        #expect(menu.moves.isEmpty)
        #expect(menu.visible.map(\.name) == ["site"])
    }
}
