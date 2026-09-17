import Foundation
import Testing
@testable import Core

@Suite("Build identity")
struct BuildIdentityTests {
    @Test("A build with nothing stamped on it says so, rather than repeating the placeholder")
    func localBuildIsNotAVersion() {
        let identity = BuildIdentity.read(
            version: "0.1.0", build: "1", buildChannel: "local", masterCommit: nil
        )

        #expect(identity == .local)
        #expect(identity.line == "Development build")
        #expect(identity.isRelease == false)
    }

    @Test("A missing channel is a local build too")
    func missingChannelIsLocal() {
        #expect(
            BuildIdentity.read(version: "0.1.0", build: "1", buildChannel: nil, masterCommit: nil)
                == .local
        )
    }

    @Test("The release workflow's stamp is the only thing that produces a version")
    func releaseCarriesItsVersion() {
        let identity = BuildIdentity.read(
            version: "0.2.0", build: "431", buildChannel: "release", masterCommit: nil
        )

        #expect(identity == .release(version: "0.2.0", build: "431"))
        #expect(identity.line == "Version 0.2.0 · Build 431")
        #expect(identity.value == "0.2.0 (431)")
        #expect(identity.isRelease)
    }

    @Test("A build number equal to the version is not printed twice")
    func repeatedBuildNumberIsDropped() {
        let identity = BuildIdentity.read(
            version: "1.0", build: "1.0", buildChannel: "release", masterCommit: nil
        )

        #expect(identity.line == "Version 1.0")
        #expect(identity.value == "1.0")
    }

    @Test("The master copy names the commit it was built from, shortened the way git shows it")
    func masterNamesItsCommit() {
        let identity = BuildIdentity.read(
            version: "0.1.0", build: "1", buildChannel: "local", masterCommit: "10320b4c9f1e2a3"
        )

        #expect(identity == .master(commit: "10320b4c9f1e2a3"))
        #expect(identity.line == "Development build · 10320b4")
        #expect(identity.value == identity.line)
    }

    @Test("A master commit outranks a release channel")
    func masterCommitWins() {
        let identity = BuildIdentity.read(
            version: "0.2.0", build: "431", buildChannel: "release", masterCommit: "deadbeef1"
        )

        #expect(identity == .master(commit: "deadbeef1"))
        #expect(identity.isRelease == false)
    }

    @Test("Blank strings count as absent, not as a version")
    func blanksAreAbsent() {
        #expect(
            BuildIdentity.read(
                version: "  ", build: "1", buildChannel: "release", masterCommit: nil
            ) == .local
        )
        #expect(
            BuildIdentity.read(
                version: "0.2.0", build: "431", buildChannel: "release", masterCommit: "   "
            ) == .release(version: "0.2.0", build: "431")
        )
    }

    @Test("A release missing its build number prints the version alone")
    func releaseWithoutBuildNumber() {
        let identity = BuildIdentity.read(
            version: "0.2.0", build: nil, buildChannel: "release", masterCommit: nil
        )

        #expect(identity.line == "Version 0.2.0")
    }

    private static let brussels = TimeZone(identifier: "Europe/Brussels")!
    private static let belgium = Locale(identifier: "en_GB")
    private static let built = Date(timeIntervalSince1970: 1_787_488_320)
    private static let now = Date(timeIntervalSince1970: 1_787_500_800)

    private static func line(_ identity: BuildIdentity, built: Date?) -> String {
        identity.line(built: built, now: now, locale: belgium, timeZone: brussels)
    }

    @Test("A development build says when it was made")
    func developmentBuildCarriesItsTimestamp() {
        #expect(Self.line(.local, built: Self.built) == "Development build · 23 Aug 14:32")
        #expect(
            Self.line(.master(commit: "10320b4c9f1e2a3"), built: Self.built)
                == "Development build · 10320b4 · 23 Aug 14:32"
        )
    }

    @Test("A release is left exactly as it was")
    func releaseNeverShowsATimestamp() {
        let identity = BuildIdentity.release(version: "0.5.0", build: "570")

        #expect(Self.line(identity, built: Self.built) == "Version 0.5.0 · Build 570")
        #expect(Self.line(identity, built: Self.built) == identity.line)
    }

    @Test("No date is the line without one, not a gap where one would go")
    func missingDateChangesNothing() {
        #expect(Self.line(.local, built: nil) == "Development build")
        #expect(
            Self.line(.master(commit: "10320b4c9f1e2a3"), built: nil)
                == "Development build · 10320b4"
        )
    }

    @Test("Reading it out of a bundle agrees with reading the keys by hand")
    func readsFromABundle() {
        #expect(BuildIdentity.read(from: Bundle.main).isRelease == false)
    }
}
