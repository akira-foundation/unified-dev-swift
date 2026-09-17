import Testing
import Foundation
@testable import Core

@Suite("Folder verdict")
struct FolderVerdictTests {
    private func facts(
        _ path: String = "/Users/tester/dev/thing",
        isRepository: Bool = false,
        enclosing: String? = nil,
        isWritable: Bool = true,
        isDirectory: Bool = true,
        exists: Bool = true,
        isAbsolute: Bool = true,
        children: [String] = []
    ) -> FolderFacts {
        FolderFacts(
            path: path,
            isRepository: isRepository,
            enclosingRepository: enclosing,
            isWritable: isWritable,
            isDirectory: isDirectory,
            exists: exists,
            isAbsolute: isAbsolute,
            homeDirectory: "/Users/tester",
            workspacesRoot: "/Users/tester/unifieddev/workspaces",
            childRepositories: children
        )
    }

    @Test("a repository is added, not offered")
    func alreadyRepository() {
        #expect(
            FolderVerdict.of(facts(isRepository: true))
                == .alreadyRepository(root: "/Users/tester/dev/thing")
        )
    }

    @Test("a folder inside a repository registers the repository")
    func registersTheTopLevel() {
        var inside = facts("/Users/tester/dev/thing/src/deep", isRepository: true)
        inside.repositoryRoot = "/Users/tester/dev/thing"

        #expect(FolderVerdict.of(inside) == .alreadyRepository(root: "/Users/tester/dev/thing"))
    }

    @Test("a plain folder is offered")
    func plainFolder() {
        #expect(FolderVerdict.of(facts()) == .offer)
    }

    @Test("a folder inside another repository is refused, and names it")
    func nested() {
        let verdict = FolderVerdict.of(facts(enclosing: "/Users/tester/dev/outer"))
        #expect(verdict == .refuse(.insideRepository("/Users/tester/dev/outer")))
        guard case .refuse(let refusal) = verdict else { return }
        #expect(refusal.alternative == "/Users/tester/dev/outer")
        #expect(refusal.sentence.contains("/Users/tester/dev/outer"))
    }

    @Test("the home directory is refused")
    func home() {
        #expect(FolderVerdict.of(facts("/Users/tester")) == .refuse(.homeDirectory))
        #expect(FolderVerdict.of(facts("/Users/tester/")) == .refuse(.homeDirectory))
    }

    @Test("system folders and the containers in a home directory are refused", arguments: [
        "/", "/Applications", "/Users", "/Volumes", "/tmp", "/var", "/opt", "/private",
        "/Volumes/Backup", "/Applications/Xcode.app", "/Users/other",
        "/Library/Fonts", "/System/Library", "/usr/local", "/etc/paths.d",
        "/Users/tester/Desktop", "/Users/tester/Documents", "/Users/tester/Downloads",
        "/Users/tester/Library", "/Users/tester/Pictures",
    ])
    func reserved(path: String) {
        #expect(FolderVerdict.of(facts(path)) == .refuse(.systemDirectory))
    }

    @Test("a project inside those containers is still fine", arguments: [
        "/Users/tester/Desktop/scratch", "/Users/tester/Documents/site", "/Users/other/code",
        "/tmp/scratch", "/Volumes/SSD/code/thing", "/opt/mine", "/private/tmp/x",
    ])
    func notReserved(path: String) {
        #expect(FolderVerdict.of(facts(path)) == .offer)
    }

    @Test("a folder that cannot be written to is refused")
    func readOnly() {
        #expect(FolderVerdict.of(facts(isWritable: false)) == .refuse(.notWritable))
    }

    @Test("something that is not a folder is refused")
    func notADirectory() {
        #expect(
            FolderVerdict.of(facts(isDirectory: false))
                == .refuse(.notADirectory("/Users/tester/dev/thing"))
        )
    }

    @Test("nothing at the path and a path that is not one get their own answers")
    func missingAndRelative() {
        #expect(
            FolderVerdict.of(facts(exists: false))
                == .refuse(.nothingThere("/Users/tester/dev/thing"))
        )
        #expect(
            FolderVerdict.of(facts("dev/thing", isAbsolute: false))
                == .refuse(.notAbsolute("dev/thing"))
        )
    }

    @Test("a folder of other people's repositories is refused rather than published")
    func containerOfProjects() {
        let verdict = FolderVerdict.of(facts(children: ["ember", "baton", "website", "mailcoach"]))
        #expect(verdict == .refuse(.containerOfProjects(["baton", "ember", "mailcoach", "website"])))
        guard case .refuse(let refusal) = verdict else { return }
        #expect(refusal.sentence.contains("baton"))
        #expect(refusal.sentence.contains("1 more"))
    }

    @Test("one or two repositories beside a project is not a container")
    func fewChildRepositories() {
        #expect(FolderVerdict.of(facts(children: ["vendored"])) == .offer)
        #expect(FolderVerdict.of(facts(children: ["vendored", "example-app"])) == .offer)
    }

    @Test("a repository in a place that is not a project is still refused")
    func repositoryDoesNotWin() {
        #expect(FolderVerdict.of(facts("/Users/tester", isRepository: true))
            == .refuse(.homeDirectory))
        #expect(FolderVerdict.of(facts("/", isRepository: true)) == .refuse(.volumeRoot))

        let worktree = facts("/Users/tester/unifieddev/workspaces/kelp", isRepository: true)
        #expect(FolderVerdict.of(worktree)
            == .refuse(.insideOurWorkspaces("/Users/tester/unifieddev/workspaces/kelp")))
    }

    @Test("a sibling of the workspaces folder is not inside it")
    func prefixIsNotContainment() {
        let sibling = facts("/Users/tester/unifieddev/workspaces-old/kelp", isRepository: true)

        #expect(FolderVerdict.of(sibling)
            == .alreadyRepository(root: "/Users/tester/unifieddev/workspaces-old/kelp"))
    }
}

@Suite("Folder refusals, said to a client")
struct FolderRefusalAgentSentenceTests {
    @Test("a folder git does not recognise is told not to make it a repository")
    func doesNotInviteGitInit() {
        let sentence = FolderRefusal.notARepositoryForAgent(path: "/Users/tester/dev/thing")

        #expect(sentence.contains("git does not recognise it as a repository"))
        #expect(sentence.contains("neither will running git init"))
        #expect(sentence.contains("retrying will not help"))
    }

    @Test("the refusals a plain folder can land on all decline git init", arguments: [
        FolderRefusal.insideRepository("/Users/tester/dev/outer"),
        .systemDirectory,
        .notWritable,
        .containerOfProjects(["ember", "baton", "mailcoach"]),
    ])
    func plainFolderRefusalsDeclineGitInit(refusal: FolderRefusal) {
        #expect(refusal.agentSentence.lowercased().contains("git init"))
    }

    @Test("the refusals a repository can land on name the alternative", arguments: [
        FolderRefusal.insideOurWorkspaces("/Users/tester/unifieddev/workspaces/kelp"),
        .homeDirectory,
        .volumeRoot,
    ])
    func repositoryRefusalsNameAnAlternative(refusal: FolderRefusal) {
        #expect(refusal.agentSentence.contains("Ask again with")
            || refusal.agentSentence.contains("instead"))
        #expect(refusal.agentSentence != refusal.sentence)
    }
}

@Suite("GitHub repository names")
struct GitHubRepositoryNameTests {
    @Test("accepts the names GitHub accepts", arguments: [
        "baton", "UnifiedDev", "laravel-medialibrary", "under_score", "dot.name", "v2.0", "a", "123",
        ".github",
    ])
    func valid(name: String) {
        #expect(GitHubRepositoryName.problem(with: name) == nil, "\(name) should be valid")
    }

    @Test("an empty name is not a name")
    func empty() {
        #expect(GitHubRepositoryName.problem(with: "") == .empty)
    }

    @Test("one hundred characters is the limit")
    func length() {
        #expect(GitHubRepositoryName.problem(with: String(repeating: "a", count: 100)) == nil)
        #expect(GitHubRepositoryName.problem(with: String(repeating: "a", count: 101)) == .tooLong)
    }

    @Test("dots on their own are paths, not names", arguments: [".", ".."])
    func reserved(name: String) {
        #expect(GitHubRepositoryName.problem(with: name) == .reserved)
    }

    @Test("a name cannot end in .git, in any case", arguments: ["thing.git", "thing.GIT", "a.Git"])
    func gitSuffix(name: String) {
        #expect(GitHubRepositoryName.problem(with: name) == .gitSuffix)
    }

    @Test("everything outside letters, digits, hyphen, underscore and dot is reported")
    func invalidCharacters() {
        #expect(GitHubRepositoryName.problem(with: "my repo") == .invalidCharacters(" "))
        #expect(GitHubRepositoryName.problem(with: "a/b") == .invalidCharacters("/"))
        #expect(GitHubRepositoryName.problem(with: "hé!") == .invalidCharacters("é!"))
        #expect(GitHubRepositoryName.problem(with: "a b c d") == .invalidCharacters(" "))
    }

    @Test("suggests a usable name from a folder name", arguments: [
        ("Baton", "Baton"),
        ("my project", "my-project"),
        ("My  Project!!", "My-Project"),
        ("the/thing", "the-thing"),
        ("trailing---", "trailing"),
        ("---leading", "leading"),
        ("dotted.", "dotted"),
        ("thing.git", "thing"),
        (".github", ".github"),
        ("...", "repository"),
        ("", "repository"),
        ("!!!", "repository"),
    ])
    func suggestion(folder: String, expected: String) {
        #expect(GitHubRepositoryName.suggestion(from: folder) == expected)
    }

    @Test("every suggestion is itself a valid name", arguments: [
        "my project", "a b!c/d", "ünïcode", "....", "x" + String(repeating: "y", count: 200),
    ])
    func suggestionsAreValid(folder: String) {
        let suggestion = GitHubRepositoryName.suggestion(from: folder)
        #expect(GitHubRepositoryName.problem(with: suggestion) == nil, "\(suggestion) was invalid")
    }

    @Test("a login that is not a login is refused before it reaches gh", arguments: [
        "", "-leading", "trailing-", "has space", "has/slash", "--flag",
        String(repeating: "a", count: 40),
    ])
    func implausibleLogins(login: String) {
        #expect(GitHub.isPlausibleLogin(login) == false)
    }

    @Test("real logins pass", arguments: ["freekmurze", "akira-io", "a", "a-b-c", "user123"])
    func plausibleLogins(login: String) {
        #expect(GitHub.isPlausibleLogin(login))
    }
}

@Suite("Name availability")
struct NameAvailabilityTests {
    @Test("only a taken name stops the button")
    func blocking() {
        #expect(NameAvailability.taken.blocksCreation)
        #expect(NameAvailability.available.blocksCreation == false)
        #expect(NameAvailability.checking.blocksCreation == false)
        #expect(NameAvailability.idle.blocksCreation == false)
        #expect(NameAvailability.unknown("offline").blocksCreation == false)
        #expect(NameAvailability.unknown("offline") != .available)
    }
}

@Suite("Files kept out of a first commit")
struct SensitiveFileTests {
    @Test("credentials are recognised", arguments: [
        ".env", ".env.local", ".env.production", "app/.env", "auth.json", ".npmrc", ".netrc",
        "certs/server.pem", "id_rsa", "deploy.key", "keystore.p12", "config/secrets.yml",
        ".aws/credentials", "backup.kdbx",
    ])
    func sensitive(path: String) {
        #expect(SensitiveFile.matches(path), "\(path) should be treated as a secret")
    }

    @Test("examples and public halves are not credentials", arguments: [
        ".env.example", ".env.sample", ".env.template", ".env.dist", "id_rsa.pub",
        "README.md", "src/main.swift", "package.json", "composer.json", "keys.md",
    ])
    func notSensitive(path: String) {
        #expect(SensitiveFile.matches(path) == false, "\(path) should not be treated as a secret")
    }

    @Test("a gitignore line is anchored and escaped")
    func gitignoreLines() {
        #expect(ExcludedPath(path: ".env", reason: .sensitive).gitignoreLine == "/.env")
        #expect(ExcludedPath(path: "app/.env", reason: .sensitive).gitignoreLine == "/app/.env")
        #expect(ExcludedPath(path: "#odd[1].pem", reason: .sensitive).gitignoreLine == "/#odd\\[1\\].pem")
        #expect(ExcludedPath(path: "my key.pem", reason: .sensitive).gitignoreLine == "/my\\ key.pem")
        #expect(ExcludedPath(path: "vendor/pkg", reason: .nestedRepository).gitignoreLine == "/vendor/pkg/")
    }
}

@Suite("What a first commit would hold")
struct FolderContentsTests {
    @Test("an empty folder says so")
    func empty() {
        #expect(FolderContents().isEmpty)
        #expect(FolderContents().summary == "Nothing yet, so the first commit will be empty.")
    }

    @Test("the count is an upper bound only when a gitignore will trim it")
    func summaryHedging() {
        let plain = FolderContents(fileCount: 12, byteSize: 2_048)
        #expect(plain.summary.hasPrefix("12 files"))

        let ignored = FolderContents(fileCount: 12, byteSize: 2_048, hasGitignore: true)
        #expect(ignored.summary.hasPrefix("At most 12 files"))

        let capped = FolderContents(fileCount: 50_000, byteSize: 1, truncated: true)
        #expect(capped.summary.hasPrefix("More than "))
        #expect(capped.summary.contains("files"))

        let one = FolderContents(fileCount: 1, byteSize: 10)
        #expect(one.summary.hasPrefix("1 file,"))
    }

    @Test("a big upload is called out before anything is published")
    func largeUpload() {
        #expect(FolderContents(fileCount: 10, byteSize: 1_000).isLargeUpload == false)
        #expect(FolderContents(fileCount: 6_000, byteSize: 1_000).isLargeUpload)
        #expect(FolderContents(fileCount: 10, byteSize: 200 * 1_024 * 1_024).isLargeUpload)
        #expect(FolderContents(fileCount: 10, byteSize: 1, truncated: true).isLargeUpload)
    }

    @Test("exclusions are readable by reason")
    func exclusions() {
        let contents = FolderContents(excluded: [
            ExcludedPath(path: ".env", reason: .sensitive),
            ExcludedPath(path: "vendor/pkg", reason: .nestedRepository),
        ])
        #expect(contents.sensitiveFiles == [".env"])
        #expect(contents.nestedRepositories == ["vendor/pkg"])
        #expect(contents.isEmpty == false)
    }
}
