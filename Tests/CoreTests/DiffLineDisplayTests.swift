import Foundation
import Testing
@testable import Core

struct DiffLineDisplayTests {
    @Test func anOrdinaryLineIsDrawnWhole() {
        let line = "    return $result->map(fn ($item) => ['invoice' => $item])->all();"
        #expect(DiffLineDisplay.text(line) == line)
    }

    @Test func aLineOfExactlyTheLimitIsDrawnWhole() {
        let line = String(repeating: "a", count: DiffLineDisplay.limit)
        #expect(DiffLineDisplay.text(line) == line)
    }

    @Test func aMinifiedLineIsCutAtTheLimitAndSaysHowMuchIsMissing() {
        let line = String(repeating: "var a=function(b){return b.x};", count: 120_000)
        let shown = DiffLineDisplay.text(line)

        #expect(shown.hasPrefix(String(line.prefix(DiffLineDisplay.limit))))
        #expect(shown.hasSuffix("more on this line, not shown"))
        #expect(shown.count < DiffLineDisplay.limit + 60)
    }

    @Test func aLineOfWideCharactersWithinTheLimitIsDrawnWhole() {
        let line = String(repeating: "日本語", count: 600)
        #expect(line.utf8.count > DiffLineDisplay.limit)
        #expect(DiffLineDisplay.text(line) == line)
    }

    @Test func theCutNeverSplitsACharacter() {
        let line = String(repeating: "🇦🇹👍🏽", count: DiffLineDisplay.limit)
        let kept = DiffLineDisplay.text(line).prefix(DiffLineDisplay.limit)

        #expect(kept.allSatisfy { $0 == "🇦🇹" || $0 == "👍🏽" })
    }

    @Test func noShortenedLineCanCarryWordEmphasis() {
        #expect(DiffLineDisplay.limit >= DiffParser.intraLineLimit)
    }
}
