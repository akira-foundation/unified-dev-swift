import Foundation
import Testing
@testable import Core

@Suite("Update installer")
struct UpdateInstallerTests {
    private let testDigest = "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"

    private func asset(size: Int, sha256: String?, url: URL? = nil) throws -> GitHubRelease.Asset {
        GitHubRelease.Asset(
            name: "unified_dev_1.5.0_aarch64.zip",
            downloadURL: try url ?? #require(URL(string: "https://github.com/x/y/releases/download/v1.5.0/app.zip")),
            size: size,
            sha256: sha256
        )
    }

    @Test("The checksum is SHA-256 over the whole file")
    func hashesTheFile() throws {
        let workspace = try UpdateFixture()
        defer { workspace.remove() }
        let file = try workspace.write("test", to: "download.zip")

        #expect(try UpdateInstaller.sha256Hex(of: file) == testDigest)
    }

    @Test("A download that matches its size and checksum passes")
    func matchingDownloadPasses() throws {
        let workspace = try UpdateFixture()
        defer { workspace.remove() }
        let file = try workspace.write("test", to: "download.zip")

        try UpdateInstaller.verifyDownload(file, against: try asset(size: 4, sha256: testDigest))
        try UpdateInstaller.verifyDownload(file, against: try asset(size: 4, sha256: nil))
    }

    @Test("A download of the wrong size or checksum is refused")
    func wrongDownloadIsRefused() throws {
        let workspace = try UpdateFixture()
        defer { workspace.remove() }
        let file = try workspace.write("tost", to: "download.zip")

        #expect(throws: UpdateInstaller.Trouble.sizeMismatch(expected: 5, actual: 4)) {
            try UpdateInstaller.verifyDownload(file, against: try asset(size: 5, sha256: testDigest))
        }
        #expect(throws: UpdateInstaller.Trouble.digestMismatch) {
            try UpdateInstaller.verifyDownload(file, against: try asset(size: 4, sha256: testDigest))
        }
    }

    @Test("A bundle is replaced in place only where this user can write, and never from a translocated copy")
    func replaceability() throws {
        let workspace = try UpdateFixture()
        defer { workspace.remove() }
        let writable = workspace.root.appending(path: "UnifiedDev.app")
        try FileManager.default.createDirectory(at: writable, withIntermediateDirectories: true)

        #expect(UpdateInstaller.replaceability(of: writable) == nil)
        #expect(
            UpdateInstaller.replaceability(of: URL(filePath: "/System/Applications/Calculator.app"))
                == .notWritable(path: "/System/Applications/Calculator.app")
        )
        #expect(
            UpdateInstaller.replaceability(of: URL(filePath: "/private/var/folders/x/AppTranslocation/ABC/d/UnifiedDev.app"))
                == .translocated
        )
    }

    @Test("A signed release zip is staged when its version and signature match", .tags(.subprocess))
    func stagesMatchingRelease() async throws {
        let workspace = try UpdateFixture()
        defer { workspace.remove() }
        let app = try await workspace.signedApp(version: "1.5.0", marker: "new", in: "build")
        let requirement = try await workspace.designatedRequirement(of: app)
        let zip = try await workspace.zip(app)
        let size = try #require(FileManager.default.attributesOfItem(atPath: zip.path)[.size] as? Int)

        let staged = try await UpdateInstaller.stage(
            asset: try asset(size: size, sha256: try UpdateInstaller.sha256Hex(of: zip), url: zip),
            version: try #require(ReleaseVersion("1.5.0")),
            requirement: requirement,
            workDirectory: workspace.root.appending(path: "stage")
        )

        #expect(staged.lastPathComponent == UpdateInstaller.appName)
        #expect(try workspace.marker(in: staged) == "new")
    }

    @Test("A zip signed by someone else, or carrying another version, is refused", .tags(.subprocess))
    func refusesForeignOrMislabelledRelease() async throws {
        let workspace = try UpdateFixture()
        defer { workspace.remove() }
        let app = try await workspace.signedApp(version: "1.5.0", marker: "new", in: "build")
        let requirement = try await workspace.designatedRequirement(of: app)
        let zip = try await workspace.zip(app)
        let size = try #require(FileManager.default.attributesOfItem(atPath: zip.path)[.size] as? Int)
        let download = try asset(size: size, sha256: nil, url: zip)

        await #expect(throws: UpdateInstaller.Trouble.versionMismatch(expected: "1.6.0", actual: "1.5.0")) {
            try await UpdateInstaller.stage(
                asset: download, version: try #require(ReleaseVersion("1.6.0")), requirement: requirement,
                workDirectory: workspace.root.appending(path: "stage-version")
            )
        }

        do {
            _ = try await UpdateInstaller.stage(
                asset: download, version: try #require(ReleaseVersion("1.5.0")),
                requirement: "identifier \"io.example.someone-else\"",
                workDirectory: workspace.root.appending(path: "stage-signature")
            )
            Issue.record("a foreign signature was accepted")
        } catch let trouble as UpdateInstaller.Trouble {
            guard case .signature = trouble else {
                Issue.record("expected a signature refusal, got \(trouble)")
                return
            }
        }
    }

    @Test("Only a GitHub download is staged")
    func refusesForeignDownloadHost() async throws {
        let workspace = try UpdateFixture()
        defer { workspace.remove() }
        let foreign = try asset(size: 4, sha256: nil, url: try #require(URL(string: "https://evil.example/app.zip")))

        await #expect(throws: UpdateInstaller.Trouble.download("https://evil.example/app.zip is not a GitHub download")) {
            try await UpdateInstaller.stage(
                asset: foreign, version: try #require(ReleaseVersion("1.5.0")), requirement: "identifier \"x\"",
                workDirectory: workspace.root.appending(path: "stage")
            )
        }
    }

    @Test("Paths reach the replacement script as arguments, never as script text")
    func pathsAreNotInterpolated() {
        let replacement = UpdateInstaller.Replacement(
            staged: URL(filePath: "/tmp/stage/it's \"here\"/UnifiedDev.app"),
            target: URL(filePath: "/Applications/$(touch owned)/UnifiedDev.app"),
            requirement: "identifier \"io.akira.unifieddev\"",
            log: URL(filePath: "/tmp/update.log")
        )
        let arguments = UpdateInstaller.replacementArguments(processID: 4242, replacement: replacement)

        #expect(Array(arguments.prefix(4)) == ["-f", "-c", UpdateInstaller.replacementScript, "unifieddev-update"])
        #expect(Array(arguments.dropFirst(4)) == [
            "4242", replacement.staged.path, replacement.target.path, replacement.requirement,
            UpdateInstaller.reopenCommand, replacement.log.path,
        ])
        #expect(!UpdateInstaller.replacementScript.contains("owned"))
    }

    @Test("The replacement swaps the bundle once the old process has gone and reopens it", .tags(.subprocess))
    func replacementSwapsTheBundle() async throws {
        let workspace = try UpdateFixture()
        defer { workspace.remove() }
        let staged = try await workspace.signedApp(version: "1.5.0", marker: "new", in: "stage")
        let target = try await workspace.signedApp(version: "1.4.0", marker: "old", in: "Applications")
        let requirement = try await workspace.designatedRequirement(of: staged)
        let log = workspace.root.appending(path: "Logs/update.log")

        let status = try await workspace.runReplacement(staged: staged, target: target, requirement: requirement, log: log)

        #expect(status == 0)
        #expect(try workspace.marker(in: target) == "new")
        #expect(try workspace.contents(of: target.deletingLastPathComponent()) == [UpdateInstaller.appName])
        #expect(try String(contentsOf: log, encoding: .utf8).contains("replaced"))
    }

    @Test("A copy that fails its signature check leaves the installed bundle untouched", .tags(.subprocess))
    func replacementKeepsTheOldBundleOnFailure() async throws {
        let workspace = try UpdateFixture()
        defer { workspace.remove() }
        let staged = try await workspace.signedApp(version: "1.5.0", marker: "new", in: "stage")
        let target = try await workspace.signedApp(version: "1.4.0", marker: "old", in: "Applications")
        let log = workspace.root.appending(path: "Logs/update.log")

        let status = try await workspace.runReplacement(
            staged: staged, target: target, requirement: "identifier \"io.example.someone-else\"", log: log
        )

        #expect(status != 0)
        #expect(try workspace.marker(in: target) == "old")
        #expect(try workspace.contents(of: target.deletingLastPathComponent()) == [UpdateInstaller.appName])
        #expect(try String(contentsOf: log, encoding: .utf8).contains("signature"))
    }
}
