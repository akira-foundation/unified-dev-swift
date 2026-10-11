import Testing
import Foundation
@testable import Core

@Suite("Transcript home")
struct TranscriptHomeTests {
    private let ours = URL(filePath: "/Users/ada", directoryHint: .isDirectory)

    @Test("the real app never takes its transcript home from anywhere but the owner's home")
    func realAppIgnoresTheOverride() {
        let value = TranscriptHome.overrideValue(
            bundleIdentifier: Store.primaryBundleIdentifier,
            environment: [TranscriptHome.override: "/tmp/elsewhere"],
            info: [TranscriptHome.override: "/tmp/elsewhere"]
        )
        #expect(value == nil)
        #expect(TranscriptHome.resolve(home: ours, overriddenBy: value) == ours)
    }

    @Test("a preview reads the transcripts seeded inside it")
    func previewTakesTheOverride() {
        let value = TranscriptHome.overrideValue(
            bundleIdentifier: "io.akira.unifieddev.dev.worktree-spend",
            environment: [:],
            info: [TranscriptHome.override: "/tmp/preview/transcripts"]
        )
        #expect(value == "/tmp/preview/transcripts")
        #expect(TranscriptHome.resolve(home: ours, overriddenBy: value).path == "/tmp/preview/transcripts")
    }

    @Test("the bundle is read before the environment, so a terminal cannot move a preview")
    func bundleWinsOverEnvironment() {
        let value = TranscriptHome.overrideValue(
            bundleIdentifier: "io.akira.unifieddev.dev.worktree-spend",
            environment: [TranscriptHome.override: "/tmp/from-the-shell"],
            info: [TranscriptHome.override: "/tmp/from-the-bundle"]
        )
        #expect(value == "/tmp/from-the-bundle")
    }

    @Test("nothing may be seeded without an override, so the owner's transcripts are never written to")
    func seedingNeedsAnOverride() {
        #expect(TranscriptHome.seedable(overriddenBy: nil) == nil)
        #expect(TranscriptHome.seedable(overriddenBy: "") == nil)
        #expect(TranscriptHome.seedable(overriddenBy: "/tmp/preview") != nil)
    }
}
