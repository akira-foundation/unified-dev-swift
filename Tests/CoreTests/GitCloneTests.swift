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

    private func refusal(_ remote: String) async -> String? {
        let destination = TestScratch.unique("unifieddev-clone")
        do {
            try await Git.clone(remote, into: destination)
            return nil
        } catch let shell as ShellError {
            return shell.stderr
        } catch {
            return nil
        }
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

    @Test("a transport helper is refused by us, in our own words, before git is ever launched")
    func refusesTransportHelperOurselves() async {
        let said = await refusal("ext::sh -c 'touch /tmp/unifieddev-pwned'")

        #expect(said == "refusing to clone through the 'ext' transport helper")
        #expect(!FileManager.default.fileExists(atPath: "/tmp/unifieddev-pwned"))
    }

    @Test("an address beginning with a dash is refused for being a dash, not for its scheme")
    func refusesFlagShapedAddressOurselves() async {
        let said = await refusal("--upload-pack=touch /tmp/unifieddev-pwned")

        #expect(said == "refusing to clone '--upload-pack=touch /tmp/unifieddev-pwned'")
        #expect(said?.contains("only file, https, ssh") == false)
        #expect(!FileManager.default.fileExists(atPath: "/tmp/unifieddev-pwned"))
    }

    @Test("a scheme outside the allow-list is refused by us, so the guarantee is not the UI's")
    func refusesUnsupportedSchemeOurselves() async {
        let said = await refusal("ext://sh -c 'touch /tmp/unifieddev-pwned'")

        #expect(said?.contains("only file, https, ssh addresses") == true)
        #expect(await refusal("http://mirror.example/team/app.git")?
            .contains("only file, https, ssh addresses") == true)
        #expect(await refusal("git://mirror.example/team/app.git")?
            .contains("only file, https, ssh addresses") == true)
    }

    @Test("an empty address is refused by us")
    func refusesEmptyOurselves() async {
        #expect(await refusal("") == "refusing to clone an empty address")
    }

    @Test("an address that is not a repository fails, and says so in one line")
    func failsOnNothingThere() async throws {
        let destination = TestScratch.unique("unifieddev-clone")
        let missing = TestScratch.unique("unifieddev-absent") + ".git"

        await #expect(throws: ShellError.self) {
            try await Git.clone(missing, into: destination)
        }
    }

    @Test("the cloner reports the folder it made")
    func clonerReportsTheRepository() async throws {
        let remote = try await origin()
        let destination = TestScratch.unique("unifieddev-clone")

        let cloned = try await RepositoryCloner.clone(remote, into: destination)

        #expect(cloned.path == destination)
        #expect(await Git.isRepository(destination))
    }

    @Test("the cloner removes the folder it claimed when the clone fails, and says why in a line")
    func failedCloneRemovesTheFolderItClaimed() async throws {
        let destination = TestScratch.unique("unifieddev-clone")
        let missing = TestScratch.unique("unifieddev-absent") + ".git"

        let failure = await #expect(throws: CloneFailure.self) {
            try await RepositoryCloner.clone(missing, into: destination)
        }

        #expect(failure?.message.isEmpty == false)
        #expect(failure?.message.contains("\n") == false)
        #expect(failure?.folderWasCreated == false)
        #expect(!FolderPath.exists(destination))
    }

    @Test("a folder that is already there is never claimed, so a failed clone cannot remove it")
    func refusesAFolderItDidNotClaim() async throws {
        let destination = TestScratch.unique("unifieddev-clone")
        try FileManager.default.createDirectory(
            atPath: destination, withIntermediateDirectories: true
        )
        try "keep me\n".write(
            toFile: (destination as NSString).appendingPathComponent("notes.txt"),
            atomically: true,
            encoding: .utf8
        )
        let missing = TestScratch.unique("unifieddev-absent") + ".git"

        let failure = await #expect(throws: CloneFailure.self) {
            try await RepositoryCloner.clone(missing, into: destination)
        }

        #expect(failure?.message == CloneRefusal.occupied(destination).sentence)
        #expect(TempRepo(existing: destination).read("notes.txt") == "keep me\n")
    }

    @Test("a folder holding only a .DS_Store is still not ours, so it survives a clone attempt")
    func refusesAFolderHoldingOnlyMetadata() async throws {
        let remote = try await origin()
        let destination = TestScratch.unique("unifieddev-clone")
        try FileManager.default.createDirectory(
            atPath: destination, withIntermediateDirectories: true
        )
        try "".write(
            toFile: (destination as NSString).appendingPathComponent(".DS_Store"),
            atomically: true,
            encoding: .utf8
        )

        await #expect(throws: CloneFailure.self) {
            try await RepositoryCloner.clone(remote, into: destination)
        }

        #expect(FolderPath.exists(destination))
    }

    @Test("the cloner's discard refuses a folder it is not told it created")
    func discardRefusesAFolderItDidNotCreate() throws {
        let folder = TestScratch.unique("unifieddev-keep")
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)

        RepositoryCloner.discard(folder, folderWasCreated: false)

        #expect(FolderPath.exists(folder))
    }

    @Test("the cloner's discard refuses a path too shallow to be a project folder")
    func discardRefusesAShallowPath() {
        RepositoryCloner.discard("/", folderWasCreated: true)
        RepositoryCloner.discard("/Users", folderWasCreated: true)

        #expect(FolderPath.exists("/Users"))
    }

    @Test("the cloner's discard removes a folder it created")
    func discardRemovesWhatItCreated() throws {
        let folder = TestScratch.unique("unifieddev-gone")
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)

        RepositoryCloner.discard(folder, folderWasCreated: true)

        #expect(!FolderPath.exists(folder))
    }
}
