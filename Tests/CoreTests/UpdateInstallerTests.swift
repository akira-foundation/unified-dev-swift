import Foundation
import Testing
@testable import Core

@Suite("Update installer")
struct UpdateInstallerTests {
    private func temporaryFile(_ contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "unifieddev-installer-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appending(path: "download.zip")
        try Data(contents.utf8).write(to: file)
        return file
    }

    private func asset(size: Int, sha256: String?) throws -> GitHubRelease.Asset {
        GitHubRelease.Asset(
            name: "unified_dev_1.5.0_aarch64.zip",
            downloadURL: try #require(URL(string: "https://example.invalid/unified_dev_1.5.0_aarch64.zip")),
            size: size,
            sha256: sha256
        )
    }

    private let testDigest = "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"

    @Test("The checksum is SHA-256 over the whole file")
    func hashesTheFile() throws {
        let file = try temporaryFile("test")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

        #expect(try UpdateInstaller.sha256Hex(of: file) == testDigest)
    }

    @Test("A download that matches its size and checksum passes")
    func matchingDownloadPasses() throws {
        let file = try temporaryFile("test")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

        try UpdateInstaller.verifyDownload(file, against: try asset(size: 4, sha256: testDigest))
        try UpdateInstaller.verifyDownload(file, against: try asset(size: 4, sha256: nil))
    }

    @Test("A download of the wrong size is refused before it is hashed")
    func wrongSizeIsRefused() throws {
        let file = try temporaryFile("test")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

        #expect(throws: UpdateInstaller.Trouble.sizeMismatch(expected: 5, actual: 4)) {
            try UpdateInstaller.verifyDownload(file, against: try asset(size: 5, sha256: testDigest))
        }
    }

    @Test("A download whose checksum differs from GitHub's is refused")
    func wrongDigestIsRefused() throws {
        let file = try temporaryFile("tost")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

        #expect(throws: UpdateInstaller.Trouble.digestMismatch) {
            try UpdateInstaller.verifyDownload(file, against: try asset(size: 4, sha256: testDigest))
        }
    }

    @Test("The signature has to come from the same team as the running copy")
    func signatureRequirementNamesTheTeam() {
        #expect(
            UpdateInstaller.signatureRequirement(teamID: "ABCDE12345")
                == "anchor apple generic and certificate leaf[subject.OU] = \"ABCDE12345\""
        )
    }

    @Test("Paths reach the replacement script as arguments, never as script text")
    func pathsAreNotInterpolated() throws {
        let staged = URL(filePath: "/tmp/stage/it's \"here\"/UnifiedDev.app")
        let target = URL(filePath: "/Applications/$(touch owned)/UnifiedDev.app")
        let arguments = UpdateInstaller.replacementArguments(processID: 4242, staged: staged, target: target)

        #expect(arguments.count == 6)
        #expect(arguments[0] == "-c")
        #expect(arguments[1] == UpdateInstaller.replacementScript)
        #expect(Array(arguments[3...]) == ["4242", staged.path, target.path])
        #expect(!UpdateInstaller.replacementScript.contains("owned"))
    }

    @Test("The replacement script waits for the old process and keeps the previous copy until the swap lands")
    func replacementScriptOrder() throws {
        let script = UpdateInstaller.replacementScript
        let wait = try #require(script.range(of: "kill -0"))
        let moveAside = try #require(script.range(of: "/bin/mv \"$target\" \"$previous\""))
        let moveIn = try #require(script.range(of: "/bin/mv \"$incoming\" \"$target\""))
        let removePrevious = try #require(script.range(of: "rm -rf \"$previous\"\n/usr/bin/open"))

        #expect(wait.lowerBound < moveAside.lowerBound)
        #expect(moveAside.lowerBound < moveIn.lowerBound)
        #expect(moveIn.lowerBound < removePrevious.lowerBound)
    }

    @Test("A bundle in a folder this user cannot write is not replaced in place")
    func unwritableTargetIsRefused() {
        #expect(!UpdateInstaller.canReplace(bundleAt: URL(filePath: "/System/Applications/Calculator.app")))
    }
}
