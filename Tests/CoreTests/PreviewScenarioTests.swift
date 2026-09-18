import Testing
import Foundation
@testable import Core

@Suite("Reading a preview scenario")
struct PreviewScenarioTests {
    @Test("a scenario reads with every optional part left out")
    func readsTheSmallestScenario() throws {
        let scenario = try PreviewScenario.read(Data(#"{"projects":[{"name":"harbour"}]}"#.utf8))
        #expect(scenario.welcome)
        #expect(scenario.projects == [PreviewScenario.Project(name: "harbour")])
    }

    @Test("a full scenario keeps its projects, workspaces and chats in order")
    func readsAFullScenario() throws {
        let json = """
            {"welcome": false, "projects": [{"name": "harbour", "files": {"src/a.txt": "a"},
             "commits": ["one", "two"], "remoteAhead": ["three"],
             "workspaces": [{"name": "Lighthouse", "branch": "lighthouse",
               "chats": [{"title": "Chat", "messages": [{"from": "user", "text": "hi"},
                                                         {"from": "agent", "text": "hello"}]}]}]}]}
            """
        let scenario = try PreviewScenario.read(Data(json.utf8))
        #expect(!scenario.welcome)
        let project = try #require(scenario.projects.first)
        #expect(project.files == ["src/a.txt": "a"])
        #expect(project.commits == ["one", "two"])
        #expect(project.remoteAhead == ["three"])
        #expect(project.workspaces.first?.chats.first?.messages.map(\.from) == [.user, .agent])
    }

    @Test("a file that is not JSON is unreadable, and says so")
    func refusesGarbage() {
        #expect(throws: PreviewScenarioError.self) { try PreviewScenario.read(Data("projects: []".utf8)) }
    }

    @Test("a scenario that would write outside its own folders is refused", arguments: [
        #"{"projects":[]}"#,
        #"{"projects":[{"name":"../escape"}]}"#,
        #"{"projects":[{"name":".hidden"}]}"#,
        #"{"projects":[{"name":"a"},{"name":"A"}]}"#,
        #"{"projects":[{"name":"a","files":{"/etc/hosts":"x"}}]}"#,
        #"{"projects":[{"name":"a","files":{"src/../../x":"x"}}]}"#,
        #"{"projects":[{"name":"a","files":{".git/config":"x"}}]}"#,
        #"{"projects":[{"name":"a","workspaces":[{"name":"w","branch":"bad..branch"}]}]}"#,
        #"{"projects":[{"name":"a","workspaces":[{"name":"w","branch":"main"}]}]}"#,
        #"{"projects":[{"name":"a","workspaces":[{"name":"w","branch":"x"},{"name":"v","branch":"x"}]}]}"#,
        #"{"projects":[{"name":"a","workspaces":[{"name":" ","branch":"x"}]}]}"#,
    ])
    func refusesUnsafeScenarios(json: String) {
        #expect(throws: PreviewScenarioError.self) { try PreviewScenario.read(Data(json.utf8)) }
    }

    @Test("the launch argument is read only when a path follows it")
    func readsTheArgument() {
        #expect(PreviewLaunch.scenarioPath(arguments: ["app", "--scenario", "/tmp/s.json"]) == "/tmp/s.json")
        #expect(PreviewLaunch.scenarioPath(arguments: ["app", "--scenario"]) == nil)
        #expect(PreviewLaunch.scenarioPath(arguments: ["app", "--scenario", "--snapshot"]) == nil)
        #expect(PreviewLaunch.scenarioPath(arguments: ["app"]) == nil)
    }

    @Test("only a preview with its database and workspaces inside its own root may seed")
    func onlyAPreviewMaySeed() throws {
        let root = "/tmp/wt/.build/preview"
        let info: [String: Any] = [
            PreviewIdentity.rootOverride: root,
            Store.databaseOverride: root + "/data/unifieddev.sqlite",
            WorkspacesRoot.override: root + "/workspaces",
        ]
        let preview = PreviewIdentity.bundlePrefix + "wt"
        #expect(try PreviewLaunch.root(bundleIdentifier: preview, environment: [:], info: info) == root)

        for identifier in [Store.primaryBundleIdentifier, Store.devBundleIdentifier, nil] {
            #expect(throws: PreviewScenarioError.notAPreview) {
                try PreviewLaunch.root(bundleIdentifier: identifier, environment: [:], info: info)
            }
        }
        var realDatabase = info
        realDatabase[Store.databaseOverride] = "/Users/tester/Library/Application Support/Unified Dev/unifieddev.sqlite"
        #expect(throws: PreviewScenarioError.notAPreview) {
            try PreviewLaunch.root(bundleIdentifier: preview, environment: [:], info: realDatabase)
        }
        var realWorkspaces = info
        realWorkspaces[WorkspacesRoot.override] = "/Users/tester/unifieddev/workspaces.noindex"
        #expect(throws: PreviewScenarioError.notAPreview) {
            try PreviewLaunch.root(bundleIdentifier: preview, environment: [:], info: realWorkspaces)
        }
    }

    @Test("an environment value wins over the bundle's, and an empty one counts as absent")
    func overridesPreferTheEnvironment() {
        let info: [String: Any] = ["UD_X": "bundle"]
        #expect(LaunchOverride.value("UD_X", environment: ["UD_X": "env"], info: info) == "env")
        #expect(LaunchOverride.value("UD_X", environment: ["UD_X": ""], info: info) == "bundle")
        #expect(LaunchOverride.value("UD_X", environment: [:], info: nil) == nil)
    }

    @Test("an overridden workspaces root is used as given, whatever is on disk")
    func workspacesRootOverride() {
        let root = WorkspacesRoot.resolve(home: URL(fileURLWithPath: "/Users/tester"), overriddenBy: "/tmp/wt/ws")
        #expect(root.path == "/tmp/wt/ws")
    }

    @Test("the command line prints one line per field, and refuses what it cannot use")
    func commandLine() {
        let printed = PreviewCommand.run(["identity", "--worktree", "/tmp/wt/abc", "--branch", "feat/7-x"])
        #expect(printed.status == 0)
        #expect(printed.output.contains("bundle_id=io.akira.unifieddev.dev.abc\n"))
        #expect(printed.output.contains("app_name=UD #7\n"))
        #expect(PreviewCommand.run(["identity"]).status == 1)
        #expect(PreviewCommand.run(["identity", "--worktree"]).status == 1)
        #expect(PreviewCommand.run(["nonsense"]).status == 1)
        #expect(PreviewCommand.run(["check", "/nonexistent/scenario.json"]).status == 1)
    }
}
