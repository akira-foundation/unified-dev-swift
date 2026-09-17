import Testing
@testable import Core

@Suite("Ordering the Codex models")
struct CodexModelRankTests {
    private func model(_ id: String, isDefault: Bool = false) -> CodexModel {
        CodexModel(id: id, displayName: id, isDefault: isDefault)
    }

    @Test("a newer version comes first")
    func newerFirst() {
        let ordered = CodexModelRank.ordered([
            model("gpt-5.4"), model("gpt-5.6"), model("gpt-5.5"),
        ])
        #expect(ordered.map(\.id) == ["gpt-5.6", "gpt-5.5", "gpt-5.4"])
    }

    @Test("a two-digit minor is a number, not a string")
    func twoDigitMinor() {
        let ordered = CodexModelRank.ordered([model("gpt-5.9"), model("gpt-5.10")])
        #expect(ordered.map(\.id) == ["gpt-5.10", "gpt-5.9"])
    }

    @Test("a cut-down model sits under the full one of its own version")
    func reducedBelow() {
        let ordered = CodexModelRank.ordered([
            model("gpt-5.4-mini"), model("gpt-5.4"), model("gpt-5.3-codex-spark"),
        ])
        #expect(ordered.map(\.id) == ["gpt-5.4", "gpt-5.4-mini", "gpt-5.3-codex-spark"])
    }

    @Test("version decides before size does")
    func versionBeatsSize() {
        let ordered = CodexModelRank.ordered([model("gpt-5.4"), model("gpt-5.6-mini")])
        #expect(ordered.map(\.id) == ["gpt-5.6-mini", "gpt-5.4"])
    }

    @Test("variants of one version keep the order they arrived in")
    func stableAmongEquals() {
        let ordered = CodexModelRank.ordered([
            model("gpt-5.6-sol"), model("gpt-5.6-terra"), model("gpt-5.6-luna"),
        ])
        #expect(ordered.map(\.id) == ["gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna"])
    }

    @Test("the account default does not jump the queue")
    func defaultStaysPut() {
        let ordered = CodexModelRank.ordered([
            model("gpt-5.6"), model("gpt-5.4", isDefault: true),
        ])
        #expect(ordered.map(\.id) == ["gpt-5.6", "gpt-5.4"])
    }

    @Test("an id with no version at all falls to the bottom rather than the top")
    func unversionedLast() {
        let ordered = CodexModelRank.ordered([model("codex-preview"), model("gpt-5.4")])
        #expect(ordered.map(\.id) == ["gpt-5.4", "codex-preview"])
    }

    @Test("a version with no minor number is still a version")
    func majorWithNoMinor() {
        let ordered = CodexModelRank.ordered([
            model("gpt-5.6-sol"), model("gpt-6-astra"), model("gpt-5.6-terra"),
        ])
        #expect(ordered.map(\.id) == ["gpt-6-astra", "gpt-5.6-sol", "gpt-5.6-terra"])
    }

    @Test("a word inside another word is not a size")
    func wordBoundary() {
        #expect(CodexModelRank.isReduced("gpt-5.4-mini"))
        #expect(!CodexModelRank.isReduced("gpt-5.4-minimal-risk"))
        #expect(!CodexModelRank.isReduced("gpt-5.4-sparkle"))
    }
}
