import Foundation
import Testing
@testable import Core

/// Which database a binary is allowed to open, decided by which binary it is.
///
/// This is the one rule in Unified Dev whose failure costs the owner a real worktree. The fallback
/// directory used to be the constant "Unified Dev", so anything that got as far as `Store.defaultPath`
/// without `UD_DB_PATH` opened the real database: the real projects, the real worktree paths,
/// and, through `TmuxSessions.fingerprint`, the real tmux socket. One archive click out of a dev
/// build removes a worktree and offers up its branch.
///
/// `Bundle.main` cannot be varied inside one process, which is why the table is a pure function of
/// the identifier and why this suite exists at all. The wiring above it is one line.
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

    /// `Tools/dev-build.sh` puts this same path in `LSEnvironment`, so the two agree and a dev
    /// binary started by hand lands where `make dev-db` put the copy rather than somewhere new.
    @Test("the dev copy lands where dev-build.sh already points it")
    func theDevCopy() {
        #expect(name(Store.devBundleIdentifier) == "Unified Dev (Dev)")
        #expect(Store.devBundleIdentifier == "io.akira.unifieddev.dev")
    }

    /// The case nothing warned about. `swift run Unified Dev` and `.build/debug/Unified Dev` are not inside a
    /// bundle, so there is no identifier at all, and until this they resolved to the real database.
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

    /// The property that matters is not what each one is called, it is that no two of them collide.
    @Test("no two identities share a directory")
    func noneCollide() {
        let identifiers: [String?] = [
            Store.primaryBundleIdentifier, Store.devBundleIdentifier,
            "io.akira.unifieddev.snapshot", "io.akira.unifieddever", nil,
        ]
        let names = identifiers.map(name)
        #expect(Set(names).count == names.count)
    }

    /// A prefix of the real identifier is not the real identifier. `io.akira.unifieddever` would match
    /// a `hasPrefix` written in a hurry, and it must not.
    @Test("a near miss on the identifier is not a match")
    func aNearMissIsNotAMatch() {
        #expect(name("io.akira.unifieddev.dev.extra") != "Unified Dev")
        #expect(name("io.akira.unifieddev.dev.extra") != "Unified Dev (Dev)")
        #expect(name("io.akira.unifieddever") != "Unified Dev")
        #expect(name("COM.EXAMPLE.UNIFIEDDEV") != "Unified Dev")
    }
}
