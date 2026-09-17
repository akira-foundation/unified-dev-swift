import Foundation
import Testing
@testable import Core

@Suite("Database directory")
struct DatabaseDirectoryTests {
    private func name(_ identifier: String?) -> String {
        Store.databaseDirectoryName(forBundleIdentifier: identifier)
    }

    @Test("the real app keeps the directory its data is already in")
    func theRealApp() {
        #expect(name(Store.primaryBundleIdentifier) == "Unified Dev")
        #expect(Store.primaryBundleIdentifier == "io.akira.unifieddev")
    }

    @Test("the dev copy lands where dev-build.sh already points it")
    func theDevCopy() {
        #expect(name(Store.devBundleIdentifier) == "Unified Dev (Dev)")
        #expect(Store.devBundleIdentifier == "io.akira.unifieddev.dev")
    }

    @Test("a binary in no bundle gets a directory that says so")
    func unbundled() {
        #expect(name(nil) == "Unified Dev (unbundled)")
        #expect(name("") == "Unified Dev (unbundled)")
    }

    @Test("any other bundle is named after itself rather than sharing")
    func someOtherBundle() {
        #expect(name("io.akira.unifieddev.snapshot") == "Unified Dev (io.akira.unifieddev.snapshot)")
        #expect(name("com.apple.dt.xctest.tool") == "Unified Dev (com.apple.dt.xctest.tool)")
    }

    @Test("no two identities share a directory")
    func noneCollide() {
        let identifiers: [String?] = [
            Store.primaryBundleIdentifier, Store.devBundleIdentifier,
            "io.akira.unifieddev.snapshot", "io.akira.unifieddever", nil,
        ]
        let names = identifiers.map(name)
        #expect(Set(names).count == names.count)
    }

    @Test("a near miss on the identifier is not a match")
    func aNearMissIsNotAMatch() {
        #expect(name("io.akira.unifieddev.dev.extra") != "Unified Dev")
        #expect(name("io.akira.unifieddev.dev.extra") != "Unified Dev (Dev)")
        #expect(name("io.akira.unifieddever") != "Unified Dev")
        #expect(name("COM.EXAMPLE.UNIFIEDDEV") != "Unified Dev")
    }
}
