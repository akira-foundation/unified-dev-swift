import Testing
import Foundation
@testable import Core

@Suite("A project target, from one field")
struct ProjectTargetTests {
    private let home = "/Users/tester"
    private let location = "/Users/tester/dev/code"
    private let workspaces = "/Users/tester/unifieddev/workspaces"

    @Test("a bare name is a project in the folder the other projects are in")
    func aNameGoesToTheDefaultLocation() {
        let target = ProjectTarget.resolve("sparkline", defaultLocation: location, home: home)
        #expect(target == ProjectTarget(name: "sparkline", location: location))
    }

    @Test("a name is trimmed, and a name with spaces in it is still a name")
    func aNameIsTrimmed() {
        let target = ProjectTarget.resolve("  my app  ", defaultLocation: location, home: home)
        #expect(target == ProjectTarget(name: "my app", location: location))
    }

    @Test("a name and the path it makes resolve to the same target")
    func aNameAndItsPathAgree() {
        let byName = ProjectTarget.resolve("sparkline", defaultLocation: location, home: home)
        let byPath = ProjectTarget.resolve(
            "~/dev/code/sparkline", defaultLocation: location, home: home
        )
        #expect(byName == byPath)
    }

    @Test("a tilde is expanded against the home it was told about, not the process's")
    func aTildeIsExpanded() {
        let target = ProjectTarget.resolve("~/scratch/spike", defaultLocation: location, home: home)
        #expect(target == ProjectTarget(name: "spike", location: "/Users/tester/scratch"))
    }

    @Test("a trailing slash and a dot component do not become part of the name")
    func aPathIsStandardised() {
        for line in ["~/dev/code/sparkline/", "~/dev/code/./sparkline"] {
            let target = ProjectTarget.resolve(line, defaultLocation: location, home: home)
            #expect(target.name == "sparkline", "for \(line)")
            #expect(target.location == "/Users/tester/dev/code", "for \(line)")
        }
    }

    @Test("an absolute path is read as one wherever it points")
    func anAbsolutePath() {
        let target = ProjectTarget.resolve("/opt/things/thing", defaultLocation: location, home: home)
        #expect(target == ProjectTarget(name: "thing", location: "/opt/things"))
    }

    @Test("a relative path is a place Unified Dev cannot find, not a name it will not take")
    func aRelativePath() {
        let target = ProjectTarget.resolve("dev/sparkline", defaultLocation: location, home: home)
        #expect(target.name == "sparkline")
        #expect(target.location == "dev")
        #expect(ProjectTargetVerdict.of(facts(from: target)) == .refuse(.target(.locationNotAbsolute("dev"))))
    }

    @Test("an empty line is a name that has not been given yet")
    func anEmptyLine() {
        let target = ProjectTarget.resolve("   ", defaultLocation: location, home: home)
        #expect(target == ProjectTarget(name: "", location: location))
        #expect(ProjectTargetVerdict.of(facts(from: target)) == .refuse(.target(.noName)))
    }

    @Test("nothing at the path is a project to create")
    func createsWhereThereIsNothing() {
        let verdict = ProjectTargetVerdict.of(facts())
        #expect(verdict == .create(makesLocation: false))
        #expect(verdict.buttonTitle == "Create Project")
        #expect(verdict.opensAWorkspace)
        #expect(verdict.makesACommit)
    }

    @Test("a folder that is there and empty is used as it is")
    func adoptsAnEmptyFolder() {
        let verdict = ProjectTargetVerdict.of(facts(exists: true, isDirectory: true, isEmpty: true))
        #expect(verdict == .adopt)
        #expect(verdict.buttonTitle == "Create Project")
        #expect(verdict.opensAWorkspace)
    }

    @Test("a git repository is added, and nothing is written to it")
    func addsARepository() {
        let verdict = ProjectTargetVerdict.of(
            facts(exists: true, isDirectory: true, isRepository: true)
        )
        #expect(verdict == .add(root: "/Users/tester/dev/code/sparkline"))
        #expect(verdict.buttonTitle == "Add Project")
        #expect(!verdict.opensAWorkspace)
        #expect(!verdict.makesACommit)
    }

    @Test("a folder with work in it and no repository is tracked")
    func tracksAFolderWithFilesInIt() {
        let verdict = ProjectTargetVerdict.of(facts(exists: true, isDirectory: true))
        #expect(verdict == .track)
        #expect(verdict.buttonTitle == "Start Tracking")
        #expect(verdict.makesACommit)
        #expect(!verdict.opensAWorkspace)
    }

    @Test("the folder projects live in is refused while a project inside it is created")
    func theDefaultLocationIsRefusableAndItsChildrenAreNot() {
        let parent = ProjectTargetVerdict.of(
            facts(
                path: location, exists: true, isDirectory: true,
                children: ["ableton-mcp", "ansible", "unifieddev", "ember"]
            )
        )
        #expect(parent == .refuse(.folder(.containerOfProjects(
            ["ableton-mcp", "ansible", "ember", "unifieddev"]
        ))))
        #expect(parent.buttonTitle == "Add Project")
        #expect(ProjectTargetVerdict.of(facts()) == .create(makesLocation: false))
    }

    @Test("a folder inside a repository is refused, and the repository is offered")
    func offersTheEnclosingRepository() {
        let verdict = ProjectTargetVerdict.of(
            facts(
                path: "/Users/tester/dev/code/unifieddev/Tools",
                exists: true, isDirectory: true, enclosing: "/Users/tester/dev/code/unifieddev"
            )
        )
        guard case .refuse(let refusal) = verdict else {
            Issue.record("not refused: \(verdict)")
            return
        }
        #expect(refusal.alternative == "/Users/tester/dev/code/unifieddev")
        #expect(refusal.sentence.contains("/Users/tester/dev/code/unifieddev"))
    }

    @Test("the home folder is refused by the rule that knows what is in it")
    func refusesTheHomeFolder() {
        let verdict = ProjectTargetVerdict.of(
            facts(path: home, exists: true, isDirectory: true)
        )
        #expect(verdict == .refuse(.folder(.homeDirectory)))
    }

    @Test("a target that does not exist yet is judged by the new project rules")
    func refusesByTheOtherList() {
        let inside = ProjectTargetVerdict.of(
            facts(path: "/Users/tester/unifieddev/workspaces/thing")
        )
        #expect(inside == .refuse(.target(.insideOurWorkspaces("~/unifieddev/workspaces/thing"))))
        #expect(inside.buttonTitle == "Create Project")

        let hidden = ProjectTargetVerdict.of(facts(name: ".hidden"))
        #expect(hidden == .refuse(.target(.nameIsHidden(".hidden"))))
    }

    @Test("no refusal sends the reader to the other door")
    func nothingNamesTheOtherDoor() {
        let refusals: [ProjectTargetRefusal] = [
            .target(.noName), .target(.nameHasSeparator("a:b")), .target(.nameIsHidden(".x")),
            .target(.noLocation), .target(.locationNotAbsolute("dev")),
            .target(.somethingThere("~/x")), .target(.insideRepository("~/y")),
            .target(.insideOurWorkspaces("~/z")), .target(.reservedLocation("~/Desktop")),
            .target(.notWritable("/opt")),
            .folder(.homeDirectory), .folder(.systemDirectory), .folder(.notWritable),
            .folder(.containerOfProjects(["a", "b", "c"])),
            .folder(.insideRepository("/Users/tester/dev/code/unifieddev")),
        ]
        for refusal in refusals {
            #expect(!refusal.sentence.isEmpty, "\(refusal)")
            #expect(refusal.sentence.hasSuffix("."), "\(refusal)")
            #expect(!refusal.sentence.lowercased().contains("add it as a project"), "\(refusal)")
            #expect(!refusal.sentence.lowercased().contains("location field"), "\(refusal)")
        }
    }

    @Test("before anything is typed the block says where a project would go, and that a path works")
    func theOpeningSentence() {
        let none = ProjectConsequence.opening(location: location, projectsThere: 0, home: home)
        #expect(none.tone == .waiting)
        #expect(none.detail.hasPrefix("New projects go in ~/dev/code."))
        #expect(none.detail.contains("point at a folder you already have"))

        let one = ProjectConsequence.opening(location: location, projectsThere: 1, home: home)
        #expect(one.detail.contains("where your other project lives"))

        let several = ProjectConsequence.opening(location: location, projectsThere: 3, home: home)
        #expect(several.detail.contains("where 3 of your projects live"))
    }

    @Test("a project about to be created says the whole path and what will happen to it")
    func theCreateBlock() {
        let said = ProjectConsequence.of(
            .create(makesLocation: true),
            path: "/Users/tester/Developer/sparkline",
            home: home,
            branch: "main"
        )
        #expect(said.lead == "~/Developer/sparkline. Unified Dev will create both.")
        #expect(said.detail.contains("empty first commit on main"))
        #expect(said.detail.contains("no README, no .gitignore"))
        #expect(said.tone == .going)
    }

    @Test("a repository about to be added says that nothing is written to it")
    func theAddBlock() {
        let said = ProjectConsequence.of(
            .add(root: "/Users/tester/dev/code/unifieddev"), path: "/Users/tester/dev/code/unifieddev",
            home: home, branch: "main"
        )
        #expect(said.lead == "~/dev/code/unifieddev is a git repository.")
        #expect(said.detail.contains("Nothing is written to it"))
        #expect(said.excluded.isEmpty)
    }

    @Test("a folder about to be tracked says what goes in and what is kept out")
    func theTrackBlock() {
        var contents = FolderContents(fileCount: 34, byteSize: 1_258_291)
        contents.excluded = [ExcludedPath(path: ".env", reason: .sensitive)]

        let waiting = ProjectConsequence.of(
            .track, path: "/Users/tester/dev/notes", home: home, branch: "main"
        )
        #expect(waiting.lead == "~/dev/notes has files in it and is not a repository.")
        #expect(waiting.tone == .caution)
        #expect(waiting.detail.hasSuffix("."))
        #expect(waiting.excluded.isEmpty)

        let counted = ProjectConsequence.of(
            .track, path: "/Users/tester/dev/notes", home: home, branch: "main", contents: contents
        )
        #expect(counted.detail.contains(contents.summary))
        #expect(counted.detail.contains("Kept out and added to .gitignore"))
        #expect(counted.excluded.count == 1)
    }

    @Test("a refusal is the sentence, at the length it was written")
    func theRefusalBlock() {
        let said = ProjectConsequence.of(
            .refuse(.folder(.containerOfProjects(["a", "b", "c"]))),
            path: location, home: home, branch: "main"
        )
        #expect(said.lead == nil)
        #expect(said.tone == .refusal)
        #expect(said.detail == FolderRefusal.containerOfProjects(["a", "b", "c"]).sentence)
    }

    private func facts(
        name: String = "sparkline",
        location: String? = nil,
        path: String? = nil,
        exists: Bool = false,
        isDirectory: Bool = false,
        isEmpty: Bool = false,
        isRepository: Bool = false,
        enclosing: String? = nil,
        children: [String] = []
    ) -> NewProjectFacts {
        let folder = location ?? self.location
        return NewProjectFacts(
            name: name,
            location: folder,
            path: path ?? (folder as NSString).appendingPathComponent(name),
            locationExists: true,
            targetExists: exists,
            targetIsDirectory: isDirectory,
            targetIsEmpty: isEmpty,
            targetIsRepository: isRepository,
            enclosingRepository: enclosing,
            nearestExistingAncestor: folder,
            isAncestorWritable: true,
            isTargetWritable: true,
            homeDirectory: home,
            workspacesRoot: workspaces,
            childRepositories: children
        )
    }

    private func facts(from target: ProjectTarget) -> NewProjectFacts {
        let path = NewProjectPlan.target(
            name: target.name, location: target.location, home: home
        ) ?? ""
        return NewProjectFacts(
            name: target.name,
            location: target.location,
            path: path,
            locationExists: true,
            nearestExistingAncestor: target.location,
            isAncestorWritable: true,
            homeDirectory: home,
            workspacesRoot: workspaces
        )
    }
}
