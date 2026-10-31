import Testing
@testable import Core

@Suite("SeaDiscoveries")
struct SeaDiscoveriesTests {
    private let coral = Ocean(name: "Coral Sea", slug: "coral-sea", latitude: -18, longitude: 152)
    private let workspace = WorkspaceID("w1")

    @Test("a first sail is marked on its workspace, with the sentence the notice used to say")
    func marksAFirstSail() {
        var discoveries = SeaDiscoveries()
        let pick = OceanPick(ocean: coral, isFirstUse: true, remainingUndiscovered: 2)

        discoveries.record(pick, for: workspace)

        #expect(discoveries.label(for: workspace) == pick.notice)
        #expect(discoveries.label(for: WorkspaceID("w2")) == nil)
    }

    @Test("a sea sailed before leaves no mark")
    func ignoresAReturn() {
        var discoveries = SeaDiscoveries()

        discoveries.record(OceanPick(ocean: coral, isFirstUse: false, remainingUndiscovered: 2), for: workspace)
        discoveries.record(nil, for: workspace)

        #expect(discoveries.label(for: workspace) == nil)
    }

    @Test("the mark stays while the workspace is open and goes once the selection leaves it")
    func clearsOnLeaving() {
        var discoveries = SeaDiscoveries()
        discoveries.record(OceanPick(ocean: coral, isFirstUse: true, remainingUndiscovered: 0), for: workspace)

        discoveries.leave(workspace, for: workspace)
        discoveries.leave(nil, for: WorkspaceID("w2"))
        #expect(discoveries.label(for: workspace) != nil)

        discoveries.leave(workspace, for: WorkspaceID("w2"))
        #expect(discoveries.label(for: workspace) == nil)
    }

    @Test("leaving for home clears the mark too")
    func clearsOnLeavingForHome() {
        var discoveries = SeaDiscoveries()
        discoveries.record(OceanPick(ocean: coral, isFirstUse: true, remainingUndiscovered: 5), for: workspace)

        discoveries.leave(workspace, for: nil)

        #expect(discoveries.label(for: workspace) == nil)
    }
}
