import Foundation
import Testing
@testable import Core

@Suite("A preview scenario that seeds suggested work")
struct PreviewScenarioSuggestionTests {
    private func chat(_ suggestions: [PreviewScenario.Suggestion]) -> PreviewScenario {
        PreviewScenario(projects: [
            PreviewScenario.Project(name: "lantern", workspaces: [
                PreviewScenario.Workspace(name: "w", branch: "w", chats: [
                    PreviewScenario.Chat(title: "Import", messages: [], suggestions: suggestions),
                ]),
            ]),
        ])
    }

    @Test("a scenario reads hidden projects, loose folders and suggestions, each optional")
    func reads() throws {
        let scenario = try PreviewScenario.read(Data(#"""
            {"looseRepositories":["tidewater"],"looseFolders":["driftwood"],
             "projects":[
               {"name":"lantern","workspaces":[{"name":"w","branch":"w","chats":[
                 {"title":"Import","messages":[],"suggestions":[
                   {"title":"Keep the last row","why":"Because.","prompt":"Do it."},
                   {"title":"Share","why":"Because.","prompt":"Do it.","looseRepository":"tidewater","state":"withdrawn"},
                   {"title":"Sort","why":"Because.","prompt":"Do it.","looseFolder":"driftwood","state":"started","startedIn":"w"}]}]}]},
               {"name":"almanac","hidden":true}]}
            """#.utf8))
        let suggestions = scenario.projects[0].workspaces[0].chats[0].suggestions

        #expect(scenario.looseRepositories == ["tidewater"])
        #expect(scenario.looseFolders == ["driftwood"])
        #expect(scenario.projects.map(\.hidden) == [false, true])
        #expect(suggestions.map(\.title) == ["Keep the last row", "Share", "Sort"])
        #expect(suggestions.map(\.state) == [.pending, .withdrawn, .started])
        #expect(suggestions.map(\.looseRepository) == [nil, "tidewater", nil])
        #expect(suggestions.map(\.looseFolder) == [nil, nil, "driftwood"])
        #expect(suggestions.map(\.startedIn) == [nil, nil, "w"])
    }

    @Test("a suggestion that names nothing the scenario makes is refused before anything is made")
    func refusesWhatItCannotFind() {
        let problems = chat([
            PreviewScenario.Suggestion(title: "A", why: "B", prompt: "C", project: "nowhere"),
            PreviewScenario.Suggestion(title: "D", why: "E", prompt: "F", looseRepository: "tidewater"),
            PreviewScenario.Suggestion(title: "G", why: "H", prompt: "I", project: "lantern", looseRepository: "tidewater"),
            PreviewScenario.Suggestion(title: " ", why: "H", prompt: "I"),
            PreviewScenario.Suggestion(title: "J", why: "K", prompt: "L", looseFolder: "driftwood"),
            PreviewScenario.Suggestion(title: "M", why: "N", prompt: "O", state: .started),
            PreviewScenario.Suggestion(title: "P", why: "Q", prompt: "R", state: .started, startedIn: "elsewhere"),
        ]).problems

        #expect(problems.contains { $0.contains("\"nowhere\"") })
        #expect(problems.contains { $0.contains("a loose repository the scenario does not make") })
        #expect(problems.contains { $0.contains("both a project and a loose repository") })
        #expect(problems.contains { $0.contains("missing its title, its reason or its prompt") })
        #expect(problems.contains { $0.contains("a loose folder the scenario does not make") })
        #expect(problems.contains { $0.contains("\"M\"") && $0.contains("must name the workspace it started in") })
        #expect(problems.contains { $0.contains("\"elsewhere\", which is not a workspace of its project") })
    }

    @Test("a loose folder named twice, or named like a project, is refused")
    func refusesCollidingLooseFolders() {
        let problems = PreviewScenario(
            projects: [PreviewScenario.Project(name: "lantern")],
            looseRepositories: ["tidewater", "lantern"],
            looseFolders: ["Tidewater", "../out"]
        ).problems

        #expect(problems.contains { $0.contains("\"Tidewater\" is named twice") })
        #expect(problems.contains { $0.contains("\"lantern\" has the name of a project") })
        #expect(problems.contains { $0.contains("\"../out\" is not a plain folder name") })
    }

    @Test("more suggestions waiting in one workspace than Unified Dev keeps is refused")
    func refusesTooMany() {
        let six = (1...WorkSuggestion.undecidedLimit + 1).map {
            PreviewScenario.Suggestion(title: "Work \($0)", why: "W", prompt: "P")
        }

        #expect(chat(six).problems.contains { $0.contains("more than \(WorkSuggestion.undecidedLimit)") })
    }
}

@Suite("Seeding suggested work into a preview", .tags(.git, .subprocess), .scratchDirectory, .timeLimit(.minutes(1)))
struct PreviewScenarioSuggestionSeedingTests {
    @Test("each kind of suggestion arrives as a card in its chat, with the projects and folders it names")
    func seedsEveryKind() async throws {
        let root = TestScratch.unique("preview-suggestions")
        let manager = WorkspaceManager(
            store: try makeTestStore("preview-suggestions"),
            workspacesRoot: URL(fileURLWithPath: root + "/workspaces", isDirectory: true)
        )
        let seeder = PreviewScenarioSeeder(manager: manager, scratchRoot: PreviewIdentity.scratch(in: root))
        let scenario = PreviewScenario(
            projects: [
                PreviewScenario.Project(name: "lantern", workspaces: [
                    PreviewScenario.Workspace(name: "Importer", branch: "importer", chats: [
                        PreviewScenario.Chat(
                            title: "Import",
                            messages: [PreviewScenario.Line(from: .agent, text: "I found some things.")],
                            suggestions: [
                                PreviewScenario.Suggestion(title: "Rename", why: "W", prompt: "P", state: .withdrawn),
                                PreviewScenario.Suggestion(title: "Keep the last row", why: "W", prompt: "P"),
                                PreviewScenario.Suggestion(title: "Tidy the docs", why: "W", prompt: "P", project: "almanac"),
                                PreviewScenario.Suggestion(
                                    title: "Share the tide table", why: "W", prompt: "P", looseRepository: "tidewater"
                                ),
                                PreviewScenario.Suggestion(title: "Sort the wood", why: "W", prompt: "P", looseFolder: "driftwood"),
                                PreviewScenario.Suggestion(title: "Fix parsekit", why: "W", prompt: "P", project: "octo/parsekit"),
                                PreviewScenario.Suggestion(title: "Drop", why: "W", prompt: "P", state: .dismissed),
                                PreviewScenario.Suggestion(
                                    title: "Light it", why: "W", prompt: "P", state: .started, startedIn: "Lamp"
                                ),
                            ]
                        ),
                    ]),
                    PreviewScenario.Workspace(name: "Lamp", branch: "lamp"),
                ]),
                PreviewScenario.Project(name: "almanac", hidden: true),
            ],
            looseRepositories: ["tidewater"],
            looseFolders: ["driftwood"]
        )

        let outcome = try await seeder.seed(scenario)

        let store = manager.store
        let repos = try await store.repos()
        let almanac = try #require(repos.first { $0.name == "almanac" })
        let lantern = try #require(repos.first { $0.name == "lantern" })
        let workspaces = try await store.workspaces(repoID: lantern.id)
        let importer = try #require(workspaces.first { $0.branch == "importer" })
        let lamp = try #require(workspaces.first { $0.branch == "lamp" })
        let chat = try #require(try await store.sessions(workspaceID: importer.id).first)
        let suggestions = try await store.workSuggestions(sessionID: chat.id)
        let messages = try await store.messages(sessionID: chat.id)
        let tidewater = seeder.looseRoot + "/tidewater"
        let driftwood = seeder.looseRoot + "/driftwood"

        #expect(outcome.suggestions == 8)
        #expect(almanac.hidden)
        #expect(!lantern.hidden)
        #expect(repos.count == 2)
        #expect(FileManager.default.fileExists(atPath: tidewater + "/.git"))
        #expect(FileManager.default.fileExists(atPath: driftwood + "/NOTES.md"))
        #expect(!FileManager.default.fileExists(atPath: driftwood + "/.git"))
        #expect(suggestions.map(\.target) == [
            .sameProject, .sameProject, .project(almanac.id), .folder(FolderPath.normalize(tidewater)),
            .folder(FolderPath.normalize(driftwood)), .remote("octo/parsekit"), .sameProject, .sameProject,
        ])
        #expect(suggestions.map(\.state) == [
            .withdrawn, .pending, .pending, .pending, .pending, .pending, .dismissed,
            .startedWorkspace(lamp.id, name: "Lamp"),
        ])
        #expect(messages.map(\.kind) == [.assistantText] + Array(repeating: .suggestion, count: 8))
        #expect(try await store.undecidedWorkSuggestionCounts()[importer.id] == WorkSuggestion.undecidedLimit)
    }
}
