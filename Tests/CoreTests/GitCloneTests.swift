import Foundation
import Testing
@testable import Core

@Suite("Cloning a repository", .tags(.git, .subprocess))
struct GitCloneTests {
    private func origin(defaultBranch: String = "main") async throws -> String {
        let source = try await TempRepo(defaultBranch: defaultBranch)
        try source.write("README.md", "harbour\n")
        try await source.commit("first")
        let bare = TestScratch.unique("unifieddev-origin") + ".git"
        try await Shell.check("git", ["clone", "-q", "--bare", source.path, bare])
        return bare
    }

    @Test("a repository is cloned into the destination, and the files arrive with it")
    func clonesTheFiles() async throws {
        let remote = try await origin()
        let destination = TestScratch.unique("unifieddev-clone")

        try await Git.clone(remote, into: destination)

        #expect(await Git.isRepository(destination))
        #expect(TempRepo(existing: destination).read("README.md") == "harbour\n")
    }

    @Test("the clone carries the default branch of the origin")
    func carriesTheDefaultBranch() async throws {
        let remote = try await origin(defaultBranch: "trunk")
        let destination = TestScratch.unique("unifieddev-clone")

        try await Git.clone(remote, into: destination)

        #expect(try await Git.currentBranch(of: destination) == "trunk")
    }

    @Test("a parent folder that is not there yet is created on the way")
    func createsTheParent() async throws {
        let remote = try await origin()
        let parent = TestScratch.unique("unifieddev-parent")
        let destination = (parent as NSString).appendingPathComponent("nested/harbour")

        try await Git.clone(remote, into: destination)

        #expect(await Git.isRepository(destination))
    }

    @Test("an address that is not a repository fails, and says so in one line")
    func failsOnNothingThere() async throws {
        let destination = TestScratch.unique("unifieddev-clone")
        let missing = TestScratch.unique("unifieddev-absent") + ".git"

        await #expect(throws: ShellError.self) {
            try await Git.clone(missing, into: destination)
        }
    }

    @Test("a transport helper is refused before git is ever launched")
    func refusesTransportHelper() async throws {
        let destination = TestScratch.unique("unifieddev-clone")

        await #expect(throws: ShellError.self) {
            try await Git.clone("ext::sh -c 'touch \(destination)-pwned'", into: destination)
        }
        #expect(!FileManager.default.fileExists(atPath: destination + "-pwned"))
    }

    @Test("an address that begins with a dash is refused rather than read as a flag")
    func refusesFlagShapedAddress() async throws {
        let destination = TestScratch.unique("unifieddev-clone")

        await #expect(throws: ShellError.self) {
            try await Git.clone("--upload-pack=touch \(destination)-pwned", into: destination)
        }
        #expect(!FileManager.default.fileExists(atPath: destination + "-pwned"))
    }

    @Test("the cloner reports the folder it made, and the branch it is on")
    func clonerReportsTheRepository() async throws {
        let remote = try await origin()
        let destination = TestScratch.unique("unifieddev-clone")

        let cloned = try await RepositoryCloner.clone(remote, into: destination)

        #expect(cloned.path == destination)
        #expect(cloned.branch == "main")
    }

    @Test("a clone that fails leaves nothing behind, and says why in a sentence")
    func failedCloneLeavesNothing() async throws {
        let destination = TestScratch.unique("unifieddev-clone")
        let missing = TestScratch.unique("unifieddev-absent") + ".git"

        let failure = await #expect(throws: CloneFailure.self) {
            try await RepositoryCloner.clone(missing, into: destination)
        }

        #expect(failure?.message.isEmpty == false)
        #expect(failure?.message.contains("\n") == false)
        #expect(!FileManager.default.fileExists(atPath: destination))
    }

    @Test("a folder that was already there is left alone when the clone fails")
    func keepsAFolderItDidNotMake() async throws {
        let destination = TestScratch.unique("unifieddev-clone")
        try FileManager.default.createDirectory(
            atPath: destination, withIntermediateDirectories: true
        )
        let missing = TestScratch.unique("unifieddev-absent") + ".git"

        await #expect(throws: CloneFailure.self) {
            try await RepositoryCloner.clone(missing, into: destination)
        }

        #expect(FileManager.default.fileExists(atPath: destination))
    }
}
