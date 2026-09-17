import Foundation
import Testing
@testable import Core

@Suite("Diff document")
struct DiffDocumentTests {
    private func file(_ lines: [DiffLine]) -> FileDiff {
        FileDiff(
            newPath: "Sources/Thing.swift",
            hunks: [DiffHunk(oldStart: 1, oldCount: 1, newStart: 1, newCount: 1, lines: lines)]
        )
    }

    private func line(_ kind: DiffLine.Kind, _ text: String, index: Int) -> DiffLine {
        DiffLine(kind: kind, text: text, index: index)
    }

    @Test("a comment opened by a deletion does not leak into the additions beside it")
    func carriesAreSeparatePerSide() {
        let document = DiffDocument.prepare(
            file: file([
                line(.context, "let a = 1", index: 0),
                line(.deletion, "/* opened and never closed", index: 1),
                line(.addition, "let b = 2", index: 2),
                line(.addition, "let c = 3", index: 3),
            ]),
            path: "Sources/Thing.swift"
        )

        #expect(document.carries[2] == LexState())
        #expect(document.carries[3] == LexState())
    }

    @Test("a comment opened on the new side does carry into the next new line")
    func carryFollowsItsOwnSide() {
        let document = DiffDocument.prepare(
            file: file([
                line(.addition, "/* opened here", index: 0),
                line(.addition, "still inside", index: 1),
            ]),
            path: "Sources/Thing.swift"
        )

        #expect(document.carries[0] == LexState())
        #expect(document.carries[1] != LexState())
    }

    @Test("context lines advance both sides, because they are in both versions")
    func contextAdvancesBothSides() {
        let document = DiffDocument.prepare(
            file: file([
                line(.context, "/* opened in context", index: 0),
                line(.deletion, "old inside", index: 1),
                line(.addition, "new inside", index: 2),
            ]),
            path: "Sources/Thing.swift"
        )

        #expect(document.carries[1] != LexState())
        #expect(document.carries[2] != LexState())
    }

    @Test("a file with no lexer skips the whole pass rather than running it for nothing")
    func plainTextIsFree() {
        let document = DiffDocument.prepare(
            file: file([line(.addition, "/* not code", index: 0)]),
            path: "notes.txt"
        )

        #expect(document.language == .plainText)
        #expect(document.carries.isEmpty)
    }

    @Test("a changed word is emphasised on both the old line and the new one")
    func pairedLinesGetWordRanges() throws {
        let document = DiffDocument.prepare(
            file: file([
                line(.deletion, "let total = oldValue", index: 0),
                line(.addition, "let total = newValue", index: 1),
            ]),
            path: "Sources/Thing.swift"
        )

        let deletion = try #require(document.emphasis[0])
        let addition = try #require(document.emphasis[1])

        #expect(!deletion.isEmpty)
        #expect(!addition.isEmpty)
    }

    @Test("a line with no partner is not emphasised")
    func unpairedLinesAreLeftAlone() {
        let document = DiffDocument.prepare(
            file: file([
                line(.context, "let a = 1", index: 0),
                line(.addition, "let b = 2", index: 1),
            ]),
            path: "Sources/Thing.swift"
        )

        #expect(document.emphasis[1] == nil)
    }

    @Test("two identical lines paired across a hunk are not emphasised")
    func identicalPairsAreLeftAlone() {
        let document = DiffDocument.prepare(
            file: file([
                line(.deletion, "let total = value", index: 0),
                line(.addition, "let total = value", index: 1),
            ]),
            path: "Sources/Thing.swift"
        )

        #expect(document.emphasis[0]?.isEmpty ?? true)
        #expect(document.emphasis[1]?.isEmpty ?? true)
    }

    @Test("word emphasis stops past the limit rather than costing more than the file is worth")
    func emphasisStopsAtTheLimit() {
        var lines: [DiffLine] = []
        var index = 0

        for pair in 0..<4_100 {
            lines.append(line(.deletion, "let value\(pair) = old", index: index))
            index += 1
            lines.append(line(.addition, "let value\(pair) = new", index: index))
            index += 1
        }

        let document = DiffDocument.prepare(file: file(lines), path: "Sources/Thing.swift")

        #expect(document.emphasis[0] != nil)
        #expect(document.emphasis[index - 1] == nil)
    }

    @Test("the widest line decides the scroll, and a tab is four columns of it")
    func widthCountsTabsAsFour() {
        let document = DiffDocument.prepare(
            file: file([
                line(.context, "short", index: 0),
                line(.addition, "\t\tindented", index: 1),
            ]),
            path: "Sources/Thing.swift"
        )

        #expect(document.maxColumns == 16)
    }

    @Test("a line wider than any scroller could help with is capped")
    func widthIsCapped() {
        let document = DiffDocument.prepare(
            file: file([line(.addition, String(repeating: "x", count: 5_000), index: 0)]),
            path: "Sources/Thing.swift"
        )

        #expect(document.maxColumns == 800)
    }

    @Test("the lines offered for priming are the first printed ones, with their carry")
    func primesFromTheTop() {
        let document = DiffDocument.prepare(
            file: file([
                line(.context, "/* opened", index: 0),
                line(.deletion, "gone", index: 1),
                line(.addition, "here", index: 2),
                line(.noNewline, "\\ No newline at end of file", index: 3),
            ]),
            path: "Sources/Thing.swift"
        )

        let primed = document.linesToPrime(limit: 3)
        #expect(primed.map(\.text) == ["/* opened", "gone", "here"])
        #expect(primed[0].carry == LexState())
        #expect(primed[1].carry != LexState())
        #expect(primed[2].carry != LexState())
    }

    @Test("priming stops at the limit and skips the no-newline marker")
    func primingIsBounded() {
        let document = DiffDocument.prepare(
            file: file([
                line(.addition, "one", index: 0),
                line(.addition, "two", index: 1),
                line(.noNewline, "\\ No newline at end of file", index: 2),
            ]),
            path: "Sources/Thing.swift"
        )

        #expect(document.linesToPrime(limit: 1).map(\.text) == ["one"])
        #expect(document.linesToPrime(limit: 99).map(\.text) == ["one", "two"])
        #expect(document.linesToPrime(limit: 0).isEmpty)
    }
}

@Suite("File bar layout")
struct FileBarLayoutTests {
    private let deep = "app/Domain/Channels/Jobs"

    @Test("a wide bar shows the whole path")
    func wideKeepsEverything() {
        let crumbs = FileBarLayout.crumbs(for: deep, width: 600)

        #expect(crumbs.components == ["app", "Domain", "Channels", "Jobs"])
        #expect(!crumbs.isElided)
    }

    @Test("narrowing drops components from the leading end, never the trailing")
    func trimsFromTheFront() {
        var previous = FileBarLayout.crumbs(for: deep, width: 600).components

        let floor = FileBarLayout.reserve + FileBarLayout.floor
        for width in stride(from: CGFloat(599), through: floor, by: -1) {
            let kept = FileBarLayout.crumbs(for: deep, width: width).components
            #expect(previous.suffix(kept.count) == ArraySlice(kept))
            previous = kept
        }

        #expect(previous == ["Jobs"])
    }

    @Test("the last component survives down to the floor")
    func narrowKeepsTheNearestFolder() {
        let atTheFloor = FileBarLayout.crumbs(for: deep, width: FileBarLayout.reserve + FileBarLayout.floor)

        #expect(atTheFloor.components == ["Jobs"])
        #expect(atTheFloor.isElided)
    }

    @Test("below the floor the folder is dropped rather than squeezed")
    func belowTheFloorNothingIsDrawn() {
        let tooNarrow = FileBarLayout.crumbs(for: deep, width: FileBarLayout.reserve + FileBarLayout.floor - 1)

        #expect(tooNarrow.isEmpty)
        #expect(!tooNarrow.isElided)
        #expect(FileBarLayout.crumbs(for: deep, width: 0).isEmpty)
    }

    @Test("a single component is never elided away")
    func oneComponentIsAlwaysKept() {
        let long = FileBarLayout.crumbs(for: "SupportingInfrastructure", width: FileBarLayout.reserve + FileBarLayout.floor)

        #expect(long.components == ["SupportingInfrastructure"])
        #expect(!long.isElided)
    }

    @Test("a file at the root of the worktree has no folder to show")
    func rootHasNoFolder() {
        #expect(FileBarLayout.crumbs(for: "", width: 600).isEmpty)
        #expect(!FileBarLayout.crumbs(for: "", width: 600).isElided)
    }

    @Test("empty components are not path components")
    func slashesDoNotBecomeComponents() {
        #expect(FileBarLayout.crumbs(for: "/app//Jobs/", width: 600).components == ["app", "Jobs"])
    }

    @Test("the folder uses spare room in a wide pane")
    func widthUsesAvailableSpace() {
        #expect(FileBarLayout.folderWidth(width: 4_000) == 4_000 - FileBarLayout.reserve)
        #expect(FileBarLayout.folderWidth(width: 0) == 0)
        #expect(FileBarLayout.folderWidth(width: FileBarLayout.reserve + 60) == 60)
    }
}

@Suite("Code columns")
struct CodeColumnsTests {
    @Test("a tab is four columns, so indented code is not measured short")
    func tabsAreFour() {
        #expect(CodeColumns.count(of: "\tx") == 5)
        #expect(CodeColumns.count(of: "    x") == 5)
        #expect(CodeColumns.count(of: "") == 0)
    }
}
