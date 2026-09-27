import Testing
@testable import Core

@Suite("Cutting one hunk out of a patch")
struct HunkPatchTests {
    private static let renamed = """
        diff --git a/old.txt b/new.txt
        similarity index 90%
        rename from old.txt
        rename to new.txt
        index 1111111..2222222 100644
        --- a/old.txt
        +++ b/new.txt
        @@ -1,2 +1,2 @@
        -a
        +A
         b
        @@ -9,2 +9,2 @@
         i
        -j
        +J

        """

    @Test("the last hunk keeps its lines and gets a plain header named after the destination")
    func lastHunk() throws {
        let hunk = try #require(DiffParser.parse(Self.renamed).first?.hunks.last)
        #expect(HunkPatch.isolate(hunk, from: Self.renamed) == """
            --- a/new.txt
            +++ b/new.txt
            @@ -9,2 +9,2 @@
             i
            -j
            +J

            """)
    }

    @Test("the first hunk stops where the next one starts")
    func firstHunk() throws {
        let hunk = try #require(DiffParser.parse(Self.renamed).first?.hunks.first)
        #expect(HunkPatch.isolate(hunk, from: Self.renamed) == """
            --- a/new.txt
            +++ b/new.txt
            @@ -1,2 +1,2 @@
            -a
            +A
             b

            """)
    }

    @Test("a hunk whose coordinates or lines moved is not found")
    func movedHunk() throws {
        let hunk = try #require(DiffParser.parse(Self.renamed).first?.hunks.last)
        var shifted = hunk
        shifted.oldStart = 10
        var edited = hunk
        edited.lines[1].text = "k"
        #expect(HunkPatch.isolate(shifted, from: Self.renamed) == nil)
        #expect(HunkPatch.isolate(edited, from: Self.renamed) == nil)
    }

    @Test("the no newline marker travels with its hunk")
    func noNewlineMarker() throws {
        let patch = """
            diff --git a/f.txt b/f.txt
            index 1111111..2222222 100644
            --- a/f.txt
            +++ b/f.txt
            @@ -1,2 +1,2 @@
             a
            -b
            \\ No newline at end of file
            +B
            \\ No newline at end of file

            """
        let hunk = try #require(DiffParser.parse(patch).first?.hunks.first)
        #expect(HunkPatch.isolate(hunk, from: patch) == """
            --- a/f.txt
            +++ b/f.txt
            @@ -1,2 +1,2 @@
             a
            -b
            \\ No newline at end of file
            +B
            \\ No newline at end of file

            """)
    }

    @Test("a patch of two files is not cut")
    func twoFiles() throws {
        let one = """
            diff --git a/a.txt b/a.txt
            --- a/a.txt
            +++ b/a.txt
            @@ -1 +1 @@
            -a
            +A

            """
        let two = one + one.replacingOccurrences(of: "a.txt", with: "b.txt")
        let hunk = try #require(DiffParser.parse(one).first?.hunks.first)
        #expect(HunkPatch.isolate(hunk, from: two) == nil)
    }

    @Test("a quoted destination keeps its quotes and git's trailing tab")
    func quotedPaths() {
        #expect(HunkPatch.oldSide(of: "+++ \"b/moved \\303\\251.txt\"\t") == "--- \"a/moved \\303\\251.txt\"\t")
        #expect(HunkPatch.oldSide(of: "+++ \"b/say \\\"hi\\\".txt\"") == "--- \"a/say \\\"hi\\\".txt\"")
        #expect(HunkPatch.oldSide(of: "+++ b/plain.txt") == "--- a/plain.txt")
        #expect(HunkPatch.oldSide(of: "+++ /dev/null") == nil)
    }
}
