import Foundation
import Testing
@testable import Core

@Suite("Software update")
struct SoftwareUpdateTests {
    private static let releaseJSON = """
    {
      "tag_name": "v1.5.0",
      "html_url": "https://github.com/akira-foundation/unified-dev-swift/releases/tag/v1.5.0",
      "body": "### Features\\n\\n- Something new",
      "prerelease": false,
      "draft": false,
      "assets": [
        {
          "name": "unified_dev_1.5.0_aarch64.dmg",
          "browser_download_url": "https://github.com/akira-foundation/unified-dev-swift/releases/download/v1.5.0/unified_dev_1.5.0_aarch64.dmg",
          "size": 9000,
          "digest": null
        },
        {
          "name": "unified_dev_1.5.0_aarch64.zip",
          "browser_download_url": "https://github.com/akira-foundation/unified-dev-swift/releases/download/v1.5.0/unified_dev_1.5.0_aarch64.zip",
          "size": 4096,
          "digest": "sha256:9F86D081884C7D659A2FEAA0C55AD015A3BF4F1B2B0B822CD15D6C15B0F00A08"
        }
      ]
    }
    """

    private func release(_ json: String = releaseJSON) throws -> GitHubRelease {
        try GitHubRelease.decode(Data(json.utf8))
    }

    private func current(_ text: String) throws -> ReleaseVersion {
        try #require(ReleaseVersion(text))
    }

    @Test("GitHub's latest release decodes into a version, notes and assets")
    func decodesLatestRelease() throws {
        let release = try release()

        #expect(release.tag == "v1.5.0")
        #expect(release.version.description == "1.5.0")
        #expect(release.notes.contains("Something new"))
        #expect(release.assets.count == 2)
        #expect(release.asset(named: "unified_dev_1.5.0_aarch64.zip")?.size == 4096)
    }

    @Test("The asset digest is read as lowercase hex, and a missing one stays missing")
    func readsDigest() throws {
        let release = try release()

        #expect(
            release.asset(named: "unified_dev_1.5.0_aarch64.zip")?.sha256
                == "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"
        )
        #expect(release.asset(named: "unified_dev_1.5.0_aarch64.dmg")?.sha256 == nil)
        #expect(GitHubRelease.sha256(fromDigest: "sha256:short") == nil)
        #expect(GitHubRelease.sha256(fromDigest: "md5:9f86d081") == nil)
    }

    @Test("A release whose tag is not a version is refused")
    func refusesUnversionedTag() {
        let json = Self.releaseJSON.replacingOccurrences(of: "\"v1.5.0\"", with: "\"nightly\"")
        #expect(throws: GitHubRelease.DecodingTrouble.notAVersion(tag: "nightly")) {
            try GitHubRelease.decode(Data(json.utf8))
        }
        #expect(throws: GitHubRelease.DecodingTrouble.unreadable) {
            try GitHubRelease.decode(Data("{}".utf8))
        }
    }

    @Test("A newer release with the zip for this Mac is offered for install")
    func offersNewerRelease() throws {
        let release = try release()
        let offer = SoftwareUpdate.offer(for: release, currentVersion: try current("1.4.2"), skippedVersion: nil)

        guard case .install(let offered, let asset) = offer else {
            Issue.record("expected an install offer, got \(offer)")
            return
        }
        #expect(offered.version.description == "1.5.0")
        #expect(asset.name == "unified_dev_1.5.0_aarch64.zip")
    }

    @Test("The same or an older release is not offered")
    func sameVersionIsUpToDate() throws {
        let release = try release()
        #expect(SoftwareUpdate.offer(for: release, currentVersion: try current("1.5.0"), skippedVersion: nil) == .upToDate)
        #expect(SoftwareUpdate.offer(for: release, currentVersion: try current("2.0.0"), skippedVersion: nil) == .upToDate)
    }

    @Test("A version the person skipped stays skipped")
    func skippedVersion() throws {
        let release = try release()
        #expect(
            SoftwareUpdate.offer(for: release, currentVersion: try current("1.4.0"), skippedVersion: "1.5.0")
                == .skipped(release)
        )
    }

    @Test("A prerelease or a draft is never offered")
    func prereleasesAreIgnored() throws {
        let prerelease = try release(Self.releaseJSON.replacingOccurrences(of: "\"prerelease\": false", with: "\"prerelease\": true"))
        let draft = try release(Self.releaseJSON.replacingOccurrences(of: "\"draft\": false", with: "\"draft\": true"))
        let beta = try release(Self.releaseJSON.replacingOccurrences(of: "\"v1.5.0\"", with: "\"v1.5.0-beta.1\""))

        for candidate in [prerelease, draft, beta] {
            #expect(SoftwareUpdate.offer(for: candidate, currentVersion: try current("1.4.0"), skippedVersion: nil) == .upToDate)
        }
    }

    @Test("A release with no zip for this Mac is reported rather than installed")
    func missingAsset() throws {
        let json = Self.releaseJSON.replacingOccurrences(of: "unified_dev_1.5.0_aarch64.zip", with: "unified_dev_1.5.0_x86_64.zip")
        let release = try release(json)
        #expect(
            SoftwareUpdate.offer(for: release, currentVersion: try current("1.4.0"), skippedVersion: nil)
                == .missingAsset(release)
        )
    }

    @Test("Only a stamped release build updates itself")
    func availabilityFollowsBuildIdentity() throws {
        #expect(SoftwareUpdate.availability(of: .local) == .localBuild)
        #expect(SoftwareUpdate.availability(of: .master(commit: "abc1234")) == .localBuild)
        #expect(
            SoftwareUpdate.availability(of: .release(version: "1.4.0", build: "431"))
                == .available(currentVersion: try current("1.4.0"))
        )
    }

    @Test("A check is due once a day")
    func checkIsDaily() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(SoftwareUpdate.isDue(lastCheckedAt: nil, now: now))
        #expect(!SoftwareUpdate.isDue(lastCheckedAt: now.addingTimeInterval(-3_600), now: now))
        #expect(SoftwareUpdate.isDue(lastCheckedAt: now.addingTimeInterval(-86_400), now: now))
    }

    @Test("A background check waits for every agent to finish")
    func backgroundCheckWaitsForAgents() {
        #expect(SoftwareUpdate.mayCheckInBackground(runningCount: 0))
        #expect(!SoftwareUpdate.mayCheckInBackground(runningCount: 1))
    }

    @Test("The interruption warning names what will be stopped")
    func interruptionDetail() {
        let names = (1...7).map { "workspace \($0)" }
        let detail = SoftwareUpdate.interruptionDetail(runningCount: 7, workspaceNames: names)

        #expect(SoftwareUpdate.interruptionTitle(runningCount: 1) == "An agent is still running")
        #expect(SoftwareUpdate.interruptionTitle(runningCount: 7) == "7 agents are still running")
        #expect(detail.contains("\u{2022} workspace 5"))
        #expect(!detail.contains("workspace 6"))
        #expect(detail.contains("and 2 more"))
    }

    @Test("Long release notes are shortened in the offer")
    func longNotesAreShortened() throws {
        let json = Self.releaseJSON.replacingOccurrences(
            of: "### Features\\n\\n- Something new",
            with: String(repeating: "a", count: 2_000)
        )
        let detail = SoftwareUpdate.availableDetail(try release(json), current: try current("1.4.0"))

        #expect(detail.hasPrefix("You have version 1.4.0."))
        #expect(detail.hasSuffix("\u{2026}"))
        #expect(detail.count < 1_300)
    }
}
