import Foundation
import Testing
@testable import Core

@Suite("What the update alert says")
struct SoftwareUpdatePromptTests {
    private static let releaseJSON = """
    {
      "tag_name": "v1.5.0",
      "html_url": "https://github.com/akira-foundation/unified-dev-swift/releases/tag/v1.5.0",
      "body": "### Features\\n\\n- Something new",
      "prerelease": false,
      "draft": false,
      "assets": [
        {
          "name": "unified_dev_1.5.0_aarch64.zip",
          "browser_download_url": "https://github.com/akira-foundation/unified-dev-swift/releases/download/v1.5.0/unified_dev_1.5.0_aarch64.zip",
          "size": 4096,
          "digest": null
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

    @Test("The offer carries the notes of the version it offers, as plain text")
    func offerCarriesItsNotes() throws {
        let prompt = SoftwareUpdate.prompt(
            for: SoftwareUpdate.offer(for: try release(), currentVersion: try current("1.4.0"), skippedVersion: nil),
            currentVersion: try current("1.4.0")
        )

        #expect(prompt.title == "Unified Dev 1.5.0 is available")
        #expect(prompt.detail.hasPrefix("You have version 1.4.0."))
        #expect(prompt.notes == "Features\n\n\u{2022} Something new")
    }

    @Test("The offer carries Install, Later and Skip, and nothing happens on return")
    func offerCarriesThreeButtons() throws {
        let prompt = SoftwareUpdate.prompt(
            for: SoftwareUpdate.offer(for: try release(), currentVersion: try current("1.4.0"), skippedVersion: nil),
            currentVersion: try current("1.4.0")
        )

        #expect(prompt.buttons == [.install, .later, .skip])
        #expect(prompt.defaultButton == .later)
        #expect(prompt.buttons.first == .install)
    }

    @Test("A release that published no notes says so, and points at the release page")
    func offerWithoutNotes() throws {
        let json = Self.releaseJSON.replacingOccurrences(of: "### Features\\n\\n- Something new", with: "   \\n\\n ")
        let prompt = SoftwareUpdate.prompt(
            for: SoftwareUpdate.offer(for: try release(json), currentVersion: try current("1.4.0"), skippedVersion: nil),
            currentVersion: try current("1.4.0")
        )

        #expect(prompt.notes.isEmpty)
        #expect(prompt.detail.contains("published no notes"))
        #expect(prompt.buttons == [.install, .later, .skip])
    }

    @Test("A skipped version asked for by hand is shown without the button that skipped it")
    func skippedPromptCannotSkipAgain() throws {
        let release = try release()
        let offer = SoftwareUpdate.offer(for: release, currentVersion: try current("1.4.0"), skippedVersion: "1.5.0")
        let prompt = SoftwareUpdate.prompt(for: offer, currentVersion: try current("1.4.0"))

        #expect(offer == .skipped(release))
        #expect(prompt.buttons == [.install, .later])
        #expect(prompt.defaultButton == .later)
        #expect(prompt.detail.contains("you skipped 1.5.0"))
        #expect(prompt.notes.contains("Something new"))
    }

    @Test("A skipped version can still be installed, because the zip is already named")
    func skippedOfferStaysInstallable() throws {
        let release = try release()
        let offer = SoftwareUpdate.offer(for: release, currentVersion: try current("1.4.0"), skippedVersion: "1.5.0")
        let installable = try #require(SoftwareUpdate.installable(offer))

        #expect(installable.asset.name == "unified_dev_1.5.0_aarch64.zip")
        #expect(SoftwareUpdate.installable(.upToDate) == nil)
        #expect(SoftwareUpdate.installable(.missingAsset(release)) == nil)
    }

    @Test("A release with no zip offers the release page and the skip, never an install")
    func missingAssetPrompt() throws {
        let json = Self.releaseJSON.replacingOccurrences(of: "unified_dev_1.5.0_aarch64.zip", with: "unified_dev_1.5.0_x86_64.zip")
        let prompt = SoftwareUpdate.prompt(
            for: SoftwareUpdate.offer(for: try release(json), currentVersion: try current("1.4.0"), skippedVersion: nil),
            currentVersion: try current("1.4.0")
        )

        #expect(prompt.buttons == [.releasePage, .later, .skip])
        #expect(!prompt.buttons.contains(.install))
    }

    @Test("Being up to date carries one button and no notes")
    func upToDatePrompt() throws {
        let prompt = SoftwareUpdate.prompt(for: .upToDate, currentVersion: try current("1.5.0"))

        #expect(prompt.buttons == [.close])
        #expect(prompt.notes.isEmpty)
        #expect(prompt.detail == "Version 1.5.0 is the newest release.")
    }

    @Test("Every offer that can be installed opens on Later, so return installs nothing")
    func returnNeverInstalls() throws {
        let release = try release()
        let offers: [SoftwareUpdate.Offer] = [
            SoftwareUpdate.offer(for: release, currentVersion: try current("1.4.0"), skippedVersion: nil),
            .skipped(release),
            .missingAsset(release),
        ]

        for offer in offers {
            let prompt = SoftwareUpdate.prompt(for: offer, currentVersion: try current("1.4.0"))
            #expect(prompt.defaultButton == .later)
        }
    }

    @Test("An offer names the release it is about, and being up to date names none")
    func offerNamesItsRelease() throws {
        let release = try release()
        #expect(SoftwareUpdate.Offer.skipped(release).release == release)
        #expect(SoftwareUpdate.Offer.missingAsset(release).release == release)
        #expect(SoftwareUpdate.Offer.upToDate.release == nil)
    }
}
