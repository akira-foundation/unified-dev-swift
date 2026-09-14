import Foundation
import Testing
@testable import Core

@Suite("Project folder completion", .scratchDirectory)
struct ProjectCompletionTests {
    @Test func siblingsAndPaths() throws {
        let home = TestScratch.unique("completion")
        for folder in ["Code/unifieddev", "Code/UnifiedDevTools", "Code/other", "Elsewhere/unifieddev", "Code/.unifieddev-hidden"] {
            try FileManager.default.createDirectory(atPath: home + "/" + folder, withIntermediateDirectories: true)
        }
        try Data().write(to: URL(fileURLWithPath: home + "/Code/unifieddev.txt"))
        let locations = [home + "/Code", home + "/Elsewhere", home + "/Code"]
        let matches = ProjectCompletion.matches("unif", locations: locations, home: home)
        #expect(matches.count == 3)
        #expect(Set(matches).count == 3)
        #expect(!matches.contains { $0.hasSuffix(".txt") || $0.contains(".unifieddev-hidden") })
        #expect(ProjectCompletion.matches("~/Elsewhere/unif", locations: locations, home: home) == [home + "/Elsewhere/unifieddev"])
        #expect(ProjectCompletion.matches("~/Elsewhere/", locations: [], home: home) == [home + "/Elsewhere/unifieddev"])
        #expect(ProjectCompletion.matches("", locations: locations, home: home).isEmpty)
        #expect(ProjectCompletion.matches("unif", locations: locations, home: home, limit: 1).count == 1)
        #expect(ProjectCompletion.matches("/missing/path/unif", locations: locations, home: home).isEmpty)
    }

    @Test func directoryPreferencesPersistAndInfer() async throws {
        let store = try makeTestStore("directory-preferences")
        var preferences = await DirectoryPreferences.load(from: store)
        let paths = ["/home/me/Code/one", "/home/me/Code/two", "/home/me/Other/three"]
        #expect(preferences.projectLocation(projectPaths: paths, home: "/home/me") == "/home/me/Code")
        preferences.projects = "~/Projects"
        preferences.additionalProjects = ["/more/projects"]
        preferences.ask = "/ask/here"
        try await preferences.save(to: store)
        #expect(await DirectoryPreferences.load(from: store) == preferences)
        #expect(preferences.searchLocations(projectPaths: paths, home: "/home/me") == [
            "/home/me/Code", "/home/me/Other", "/home/me/Projects", "/more/projects",
        ])
    }
}
