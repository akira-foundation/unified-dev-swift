import Foundation
import Testing
@testable import Core

@Suite("A seeded update in a preview scenario")
struct PreviewScenarioUpdateTests {
    @Test("a scenario without one seeds no update")
    func noUpdate() throws {
        let scenario = try PreviewScenario.read(Data(#"{"projects":[{"name":"a"}]}"#.utf8))
        #expect(scenario.update == nil)
    }

    @Test("a seeded update keeps the version it offers, the version it pretends to be, and its notes")
    func readsTheUpdate() throws {
        let json = #"""
            {"projects":[{"name":"a"}],
             "update":{"version":"1.1.0","current":"1.0.0","notes":"### Features\n\n- something"}}
            """#
        let scenario = try PreviewScenario.read(Data(json.utf8))

        #expect(scenario.update == PreviewScenario.Update(
            version: "1.1.0", current: "1.0.0", notes: "### Features\n\n- something"
        ))
    }

    @Test("the seeded update becomes the release GitHub would have answered with")
    func buildsTheRelease() throws {
        let update = PreviewScenario.Update(version: "1.1.0", current: "1.0.0", notes: "- something")
        let release = try #require(update.release())

        #expect(release.tag == "v1.1.0")
        #expect(release.version.description == "1.1.0")
        #expect(release.notes == "- something")
        #expect(!release.isDraft)
        #expect(!release.isPrerelease)
        #expect(GitHubRelease.isGitHubURL(release.pageURL))
        #expect(release.asset(named: "unified_dev_1.1.0_aarch64.zip") != nil)
    }

    @Test("the seeded release is offered to the version the scenario pretends to be")
    func isOffered() throws {
        let update = PreviewScenario.Update(version: "1.1.0", current: "1.0.0")
        let release = try #require(update.release())
        let current = try #require(update.currentVersion)
        let offer = SoftwareUpdate.offer(for: release, currentVersion: current, skippedVersion: nil)

        guard case .install(_, let asset) = offer else {
            Issue.record("expected an install offer, got \(offer)")
            return
        }
        #expect(asset.name == "unified_dev_1.1.0_aarch64.zip")
    }

    @Test("an update that is not a version, not newer, or a prerelease is refused, and says which")
    func refusesUnusableUpdates() throws {
        func problems(_ update: PreviewScenario.Update) -> [String] {
            PreviewScenario(projects: [.init(name: "a")], update: update).problems
        }

        #expect(problems(.init(version: "nightly", current: "1.0.0"))
            == ["the seeded update offers \"nightly\", which is not a version"])
        #expect(problems(.init(version: "1.1.0", current: "later"))
            == ["the seeded update says this copy is \"later\", which is not a version"])
        #expect(problems(.init(version: "1.0.0", current: "1.0.0"))
            == ["the seeded update offers 1.0.0 to a copy already on 1.0.0, which is nothing to offer"])
        #expect(problems(.init(version: "0.9.0", current: "1.0.0")).count == 1)
        #expect(problems(.init(version: "1.1.0-beta.1", current: "1.0.0"))
            == ["the seeded update offers 1.1.0-beta.1, and a prerelease is never offered"])
        #expect(problems(.init(version: "1.1.0", current: "1.0.0")).isEmpty)
    }

    @Test("an update that names no notes reads as one with none")
    func notesMayBeLeftOut() throws {
        let json = #"{"projects":[{"name":"a"}],"update":{"version":"1.1.0","current":"1.0.0"}}"#
        let scenario = try PreviewScenario.read(Data(json.utf8))

        #expect(scenario.update?.notes == "")
        #expect(try #require(scenario.update?.release()).notes == "")
    }
}
