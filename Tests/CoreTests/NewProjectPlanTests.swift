import Testing
import Foundation
@testable import Core

@Suite("New project location and name")
struct NewProjectPlanTests {
    private let home = "/Users/tester"

    @Test("the commonest parent of the projects already added wins")
    func commonestParent() {
        let suggestion = NewProjectPlan.suggestedLocation(
            projectPaths: [
                "/Users/tester/dev/code/unifieddev",
                "/Users/tester/scratch/spike",
                "/Users/tester/dev/code/mailcoach",
                "/Users/tester/dev/code/ember",
            ],
            home: home
        )
        #expect(suggestion == "/Users/tester/dev/code")
    }

    @Test("a tie goes to the first one, so the answer does not move about")
    func stableTie() {
        let paths = ["/Users/tester/one/a", "/Users/tester/two/b"]
        #expect(NewProjectPlan.suggestedLocation(projectPaths: paths, home: home) == "/Users/tester/one")
        #expect(NewProjectPlan.suggestedLocation(projectPaths: paths, home: home) == "/Users/tester/one")
    }

    @Test("with no projects at all it is ~/Developer")
    func fallback() {
        #expect(NewProjectPlan.suggestedLocation(projectPaths: [], home: home) == "/Users/tester/Developer")
    }

    @Test("a project at the volume root does not become the suggestion")
    func volumeRootIsNotAParent() {
        let suggestion = NewProjectPlan.suggestedLocation(
            projectPaths: ["/thing", "/Users/tester/dev/one"], home: home
        )
        #expect(suggestion == "/Users/tester/dev")
    }

    @Test("a name is trimmed and otherwise left exactly as it was typed")
    func nameIsNotSanitised() {
        #expect(NewProjectPlan.folderName(from: "  sparkline  ") == "sparkline")
        #expect(NewProjectPlan.folderName(from: "My App") == "My App")
        #expect(NewProjectPlan.folderName(from: "sparkline 2.0") == "sparkline 2.0")
    }

    @Test("the target is the location and the name, with the tilde expanded")
    func target() {
        #expect(
            NewProjectPlan.target(name: "sparkline", location: "~/Developer", home: home)
                == "/Users/tester/Developer/sparkline"
        )
        #expect(
            NewProjectPlan.target(name: " sparkline ", location: "/opt/work/", home: home)
                == "/opt/work/sparkline"
        )
        #expect(NewProjectPlan.target(name: "", location: "~/Developer", home: home) == nil)
        #expect(NewProjectPlan.target(name: "sparkline", location: "", home: home) == nil)
        #expect(NewProjectPlan.target(name: "sparkline", location: "Developer", home: home) == nil)
    }

    @Test("a path under the home directory is shown with a tilde")
    func display() {
        #expect(NewProjectPlan.display("/Users/tester/Developer/x", home: home) == "~/Developer/x")
        #expect(NewProjectPlan.display("/Users/tester", home: home) == "~")
        #expect(NewProjectPlan.display("/opt/work/x", home: home) == "/opt/work/x")
        #expect(NewProjectPlan.display("/Users/tester2/x", home: home) == "/Users/tester2/x")
    }
}

@Suite("New project verdict")
struct NewProjectVerdictTests {
    private let home = "/Users/tester"

    private func facts(
        name: String = "sparkline",
        location: String = "~/Developer",
        path: String = "/Users/tester/Developer/sparkline",
        locationExists: Bool = true,
        targetExists: Bool = false,
        targetIsDirectory: Bool = false,
        targetIsEmpty: Bool = false,
        targetIsRepository: Bool = false,
        enclosing: String? = nil,
        ancestor: String = "/Users/tester/Developer",
        isAncestorWritable: Bool = true,
        isTargetWritable: Bool = true
    ) -> NewProjectFacts {
        NewProjectFacts(
            name: name,
            location: location,
            path: path,
            locationExists: locationExists,
            targetExists: targetExists,
            targetIsDirectory: targetIsDirectory,
            targetIsEmpty: targetIsEmpty,
            targetIsRepository: targetIsRepository,
            enclosingRepository: enclosing,
            nearestExistingAncestor: ancestor,
            isAncestorWritable: isAncestorWritable,
            isTargetWritable: isTargetWritable,
            homeDirectory: home,
            workspacesRoot: "/Users/tester/unifieddev/workspaces"
        )
    }

    @Test("a path with nothing at it is created")
    func creates() {
        #expect(NewProjectVerdict.of(facts()) == .create(makesLocation: false))
    }

    @Test("a location that is not there either is said out loud, and both are made")
    func createsBoth() {
        let verdict = NewProjectVerdict.of(facts(locationExists: false, ancestor: "/Users/tester"))
        #expect(verdict == .create(makesLocation: true))
        #expect(
            verdict.hint(path: "/Users/tester/Developer/sparkline", home: home)
                == "~/Developer/sparkline. Unified Dev will create both."
        )
    }

    @Test("a folder that is there and empty is adopted rather than refused")
    func adoptsAnEmptyFolder() {
        let verdict = NewProjectVerdict.of(
            facts(targetExists: true, targetIsDirectory: true, targetIsEmpty: true)
        )
        #expect(verdict == .adopt)
        #expect(verdict.allowsCreation)
        #expect(verdict.hint(path: "/Users/tester/Developer/sparkline", home: home)
            .contains("already there and empty"))
    }

    @Test("an existing folder Unified Dev cannot write to is refused, and names itself")
    func refusesAnUnwritableFolder() {
        let verdict = NewProjectVerdict.of(
            facts(
                targetExists: true, targetIsDirectory: true, targetIsEmpty: true,
                isTargetWritable: false
            )
        )
        #expect(verdict == .refuse(.notWritable("~/Developer/sparkline")))
    }

    @Test("an existing repository and a folder with files in it are no longer this rule's to judge")
    func theTwoRedirectionsAreGone() {
        #expect(
            NewProjectVerdict.of(
                facts(targetExists: true, targetIsDirectory: true, targetIsRepository: true)
            ) == .adopt
        )
        for refusal in [NewProjectRefusal.somethingThere("~/x"), .insideRepository("~/y")] {
            #expect(!refusal.sentence.contains("add that folder as a project"), "\(refusal)")
        }
    }

    @Test("a file in the way is refused")
    func refusesAFile() {
        let verdict = NewProjectVerdict.of(facts(targetExists: true, targetIsDirectory: false))
        #expect(verdict == .refuse(.somethingThere("~/Developer/sparkline")))
    }

    @Test("a location inside another repository is refused, and names it")
    func refusesNesting() {
        let verdict = NewProjectVerdict.of(facts(enclosing: "/Users/tester/dev/outer"))
        #expect(verdict == .refuse(.insideRepository("~/dev/outer")))
        guard case .refuse(let refusal) = verdict else { return }
        #expect(refusal.sentence.contains("~/dev/outer"))
        #expect(refusal.alternative == "~/dev/outer")
        #expect(NewProjectRefusal.noName.alternative == nil)
    }

    @Test("Unified Dev's own worktree folder is refused")
    func refusesTheWorkspacesRoot() {
        let verdict = NewProjectVerdict.of(
            facts(location: "~/unifieddev/workspaces", path: "/Users/tester/unifieddev/workspaces/sparkline")
        )
        #expect(verdict == .refuse(.insideOurWorkspaces("~/unifieddev/workspaces/sparkline")))
    }

    @Test("the folders macOS and the Finder own are refused", arguments: [
        "/Users/tester/Desktop",
        "/Users/tester/Documents",
        "/Library/Preferences",
        "/Users/tester",
    ])
    func refusesReserved(path: String) {
        let verdict = NewProjectVerdict.of(facts(path: path))
        guard case .refuse(.reservedLocation) = verdict else {
            Issue.record("\(path) was not refused: \(verdict)")
            return
        }
    }

    @Test("a folder inside one of them is still allowed")
    func allowsInsideAStandardFolder() {
        #expect(
            NewProjectVerdict.of(facts(path: "/Users/tester/Documents/notes"))
                == .create(makesLocation: false)
        )
    }

    @Test("a location that cannot be written to names the folder that refused")
    func refusesUnwritable() {
        let verdict = NewProjectVerdict.of(facts(ancestor: "/opt", isAncestorWritable: false))
        #expect(verdict == .refuse(.notWritable("/opt")))
    }

    @Test("a name that is empty, a path or hidden is refused before anything else")
    func refusesTheName() {
        #expect(NewProjectVerdict.of(facts(name: "   ")) == .refuse(.noName))
        #expect(NewProjectVerdict.of(facts(name: "dev/sparkline")) == .refuse(.nameHasSeparator("dev/sparkline")))
        #expect(NewProjectVerdict.of(facts(name: "a:b")) == .refuse(.nameHasSeparator("a:b")))
        #expect(NewProjectVerdict.of(facts(name: ".hidden")) == .refuse(.nameIsHidden(".hidden")))
        #expect(NewProjectVerdict.of(facts(name: "..")) == .refuse(.nameIsHidden("..")))
    }

    @Test("no location, and one that is not a full path, are told apart")
    func refusesTheLocation() {
        #expect(NewProjectVerdict.of(facts(location: "  ", path: "")) == .refuse(.noLocation))
        #expect(
            NewProjectVerdict.of(facts(location: "Developer", path: ""))
                == .refuse(.locationNotAbsolute("Developer"))
        )
    }

    @Test("every refusal says something, ending in a full stop")
    func everyRefusalSpeaks() {
        let all: [NewProjectRefusal] = [
            .noName, .nameHasSeparator("a/b"), .nameIsHidden(".x"), .noLocation,
            .locationNotAbsolute("dev"), .somethingThere("~/x"),
            .insideRepository("~/y"), .insideOurWorkspaces("~/z"),
            .reservedLocation("~/Desktop"), .notWritable("/opt"),
        ]
        for refusal in all {
            #expect(!refusal.sentence.isEmpty, "\(refusal)")
            #expect(refusal.sentence.hasSuffix("."), "\(refusal)")
        }
    }
}
