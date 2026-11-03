import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Core

@Suite("Git.imageSides", .tags(.git, .subprocess), .scratchDirectory)
struct GitImageSidesTests {
    private func branched(_ repo: TempRepo) async throws {
        try await Shell.check("git", ["checkout", "-q", "-b", "feature"], cwd: repo.path)
    }

    private func image(_ text: String) -> ImageDiffSide {
        .image(Data(text.utf8))
    }

    @Test("a modified image answers with the base's bytes and the worktree's")
    func modified() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write("shot.png", "old")
        try await repo.commit("image")
        try await branched(repo)
        try repo.write("shot.png", "new")

        let sides = await Git.imageSides(
            worktree: repo.path, base: "main", file: ChangedFile(path: "shot.png", change: .modified)
        )

        #expect(sides == ImageDiffSides(before: image("old"), after: image("new")))
    }

    @Test("an untracked image has nothing before it, even where the base holds that path")
    func untracked() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write("shot.png", "old")
        try await repo.commit("image")
        try await branched(repo)
        try repo.write("shot.png", "new")

        let sides = await Git.imageSides(
            worktree: repo.path, base: "main", file: ChangedFile(path: "shot.png", change: .untracked)
        )

        #expect(sides == ImageDiffSides(before: .absent, after: image("new")))
    }

    @Test("bytes that are not text survive the read from git and from disk")
    func binaryBytes() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let older = Data([0x89, 0x50, 0x00, 0xFF])
        let newer = Data([0x89, 0x50, 0x00, 0xFE])
        try older.write(to: URL(filePath: repo.path + "/shot.png"))
        try await repo.commit("image")
        try await branched(repo)
        try newer.write(to: URL(filePath: repo.path + "/shot.png"))

        let sides = await Git.imageSides(
            worktree: repo.path, base: "main", file: ChangedFile(path: "shot.png", change: .modified)
        )

        #expect(sides == ImageDiffSides(before: .image(older), after: .image(newer)))
    }

    @Test("an added image the base never held has nothing before it")
    func added() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try await branched(repo)
        try repo.write("shot.png", "new")
        try await repo.commit("image")

        let sides = await Git.imageSides(
            worktree: repo.path, base: "main", file: ChangedFile(path: "shot.png", change: .added)
        )

        #expect(sides == ImageDiffSides(before: .absent, after: image("new")))
    }

    @Test("a commit scope compares against that commit")
    func sinceCommit() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write("shot.png", "base")
        try await repo.commit("image")
        try await branched(repo)
        try repo.write("shot.png", "first")
        try await repo.commit("first")
        let sha = try await Shell.check("git", ["rev-parse", "HEAD"], cwd: repo.path).trimmed
        try repo.write("shot.png", "second")
        try await repo.commit("second")
        let commit = BranchCommit(sha: sha, subject: "first", author: "a", date: Date())

        let sides = await Git.imageSides(
            worktree: repo.path, base: "main", file: ChangedFile(path: "shot.png", change: .modified),
            scope: .since(commit)
        )

        #expect(sides == ImageDiffSides(before: image("first"), after: image("second")))
    }

    @Test("a side exactly at the limit is still read")
    func atLimit() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write("shot.png", "abcd")
        try await repo.commit("image")
        try await branched(repo)
        try repo.write("shot.png", "efgh")

        let sides = await Git.imageSides(
            worktree: repo.path, base: "main", file: ChangedFile(path: "shot.png", change: .modified), limit: 4
        )

        #expect(sides == ImageDiffSides(before: image("abcd"), after: image("efgh")))
    }

    @Test("withheld paths are not drawn from either side", arguments: [".env.png", ".ssh/key.png", ".claude/shot.png"])
    func withheld(path: String) async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write(path, "old")
        try await repo.commit("image")
        try await branched(repo)
        try repo.write(path, "new")

        let sides = await Git.imageSides(
            worktree: repo.path, base: "main", file: ChangedFile(path: path, change: .modified)
        )

        #expect(sides == ImageDiffSides(before: .absent, after: .absent))
    }

    @Test("a link to a withheld file inside the worktree is not followed")
    func linkToWithheld() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write(".ssh/key.png", "secret")
        try FileManager.default.createSymbolicLink(atPath: repo.path + "/logo", withDestinationPath: ".ssh")

        let sides = await Git.imageSides(
            worktree: repo.path, base: "main", file: ChangedFile(path: "logo/key.png", change: .untracked)
        )

        #expect(sides == ImageDiffSides(before: .absent, after: .absent))
    }

    @Test("a deleted image answers with what the base held")
    func deleted() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write("shot.png", "old")
        try await repo.commit("image")
        try await branched(repo)
        try FileManager.default.removeItem(atPath: repo.path + "/shot.png")

        let sides = await Git.imageSides(
            worktree: repo.path, base: "main", file: ChangedFile(path: "shot.png", change: .deleted)
        )

        #expect(sides == ImageDiffSides(before: image("old"), after: .absent))
    }

    @Test("a renamed image is read from its old path")
    func renamed() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write("old.png", "old")
        try await repo.commit("image")
        try await branched(repo)
        try FileManager.default.moveItem(atPath: repo.path + "/old.png", toPath: repo.path + "/new.png")
        try repo.write("new.png", "new")

        let sides = await Git.imageSides(
            worktree: repo.path, base: "main",
            file: ChangedFile(path: "new.png", oldPath: "old.png", change: .renamed)
        )

        #expect(sides == ImageDiffSides(before: image("old"), after: image("new")))
    }

    @Test("a narrowed scope compares against its own revision rather than the base")
    func narrowedScope() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write("shot.png", "base")
        try await repo.commit("image")
        try await branched(repo)
        try repo.write("shot.png", "committed")
        try await repo.commit("change")
        try repo.write("shot.png", "working")

        let sides = await Git.imageSides(
            worktree: repo.path, base: "main", file: ChangedFile(path: "shot.png", change: .modified),
            scope: .uncommitted
        )

        #expect(sides == ImageDiffSides(before: image("committed"), after: image("working")))
    }

    @Test("a side over the limit is reported without its bytes")
    func overLimit() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        try repo.write("shot.png", "older bytes")
        try await repo.commit("image")
        try await branched(repo)
        try repo.write("shot.png", "newer bytes")

        let sides = await Git.imageSides(
            worktree: repo.path, base: "main", file: ChangedFile(path: "shot.png", change: .modified), limit: 4
        )

        #expect(sides == ImageDiffSides(before: .tooLarge, after: .tooLarge))
    }

    @Test("a link leading out of the worktree is not followed")
    func linkOutside() async throws {
        let repo = try await TempRepo()
        defer { repo.cleanUp() }
        let outside = try await TempRepo()
        defer { outside.cleanUp() }
        try outside.write("secret.png", "secret")
        try FileManager.default.createSymbolicLink(atPath: repo.path + "/linked", withDestinationPath: outside.path)

        let sides = await Git.imageSides(
            worktree: repo.path, base: "main", file: ChangedFile(path: "linked/secret.png", change: .untracked)
        )

        #expect(sides == ImageDiffSides(before: .absent, after: .absent))
    }
}

@Suite("ImageDiff")
struct ImageDiffTests {
    @Test("offered for a binary file with an image extension", arguments: [
        ("a/shot.png", true, true),
        ("SHOT.JPG", true, true),
        ("icon.icns", true, true),
        ("shot.png", false, false),
        ("photo.heif", true, true),
        ("bundle.zip", true, false),
    ])
    func offered(path: String, isBinary: Bool, expected: Bool) {
        #expect(ImageDiff.isOffered(path: path, isBinary: isBinary) == expected)
    }

    @Test("two sides are titled, one side stands alone")
    func columns() {
        let data = ImageDiffSide.image(Data([1]))

        #expect(ImageDiffSides(before: data, after: .tooLarge).columns == [
            ImageDiffColumn(title: "Before", side: data), ImageDiffColumn(title: "After", side: .tooLarge),
        ])
        #expect(ImageDiffSides(before: .absent, after: data).columns == [ImageDiffColumn(title: nil, side: data)])
        #expect(ImageDiffSides(before: data, after: .absent).columns == [ImageDiffColumn(title: nil, side: data)])
        #expect(ImageDiffSides(before: .absent, after: .absent).columns.isEmpty)
    }

    @Test("a lone side over the limit still gets its column")
    func loneTooLarge() {
        #expect(ImageDiffSides(before: .absent, after: .tooLarge).columns == [ImageDiffColumn(title: nil, side: .tooLarge)])
    }

    private func png(width: Int, height: Int) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @Test("bytes that are not an image decode to nothing")
    func decodeRefusesText() {
        #expect(ImageDiff.decode(Data("not an image".utf8)) == nil)
    }

    @Test("a large image is scaled to the pixel limit, keeping its shape")
    func decodeScales() throws {
        let decoded = ImageDiff.decode(try png(width: 64, height: 32), pixelLimit: 16)

        #expect(decoded?.width == 16)
        #expect(decoded?.height == 8)
    }

    @Test("an image over the area limit is refused before it is decoded, and one at the limit is not")
    func decodeRefusesArea() throws {
        let data = try png(width: 10, height: 10)

        #expect(ImageDiff.decode(data, areaLimit: 99) == nil)
        #expect(ImageDiff.decode(data, areaLimit: 100) != nil)
    }
}
