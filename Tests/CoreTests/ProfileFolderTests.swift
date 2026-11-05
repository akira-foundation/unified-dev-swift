import Foundation
import Testing
@testable import Core

@Suite("Profile folder")
struct ProfileFolderTests {
    @Test("a name becomes a lowercase ascii folder")
    func plainName() {
        #expect(ProfileFolder.name(for: "Debtges", taken: []) == "debtges")
        #expect(ProfileFolder.name(for: "Akira Foundation", taken: []) == "akira-foundation")
    }

    @Test("accents fold and punctuation goes")
    func folding() {
        #expect(ProfileFolder.name(for: "Débtges, Lda.", taken: []) == "debtges-lda")
    }

    @Test("a taken folder gets a number")
    func collision() {
        #expect(ProfileFolder.name(for: "Akira", taken: ["akira"]) == "akira-2")
        #expect(ProfileFolder.name(for: "akira", taken: ["akira", "akira-2"]) == "akira-3")
    }

    @Test("names that fold to the same folder get different ones")
    func foldedCollision() {
        let first = ProfileFolder.name(for: "Débtges", taken: [])
        let second = ProfileFolder.name(for: "Debtges", taken: [first])
        #expect(first == "debtges")
        #expect(second == "debtges-2")
    }

    @Test("the occupied folders are the names already in the root")
    func occupiedNames() throws {
        let root = URL(fileURLWithPath: TestScratch.unique("profile-root"), isDirectory: true)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("unified-dev", isDirectory: true), withIntermediateDirectories: true
        )
        #expect(ProfileFolder.occupied(under: root) == ["unified-dev"])
        #expect(ProfileFolder.occupied(under: root.appendingPathComponent("missing")).isEmpty)
    }

    @Test("a name with nothing usable still gets a folder")
    func empty() {
        #expect(ProfileFolder.name(for: "!!!", taken: []) == "profile")
        #expect(ProfileFolder.name(for: "!!!", taken: ["profile"]) == "profile-2")
    }

    @Test("the initial profile has a fixed id and is the only initial one")
    func initialProfile() {
        let initial = Profile(id: .initial, name: "Unified", folder: "unified", colour: "0A84FF", symbol: "circle")
        let other = Profile(id: ProfileID("other"), name: "Other", folder: "other", colour: "0A84FF", symbol: "circle")
        #expect(ProfileID.initial.rawValue == "unified")
        #expect(initial.isInitial)
        #expect(!other.isInitial)
    }
}
