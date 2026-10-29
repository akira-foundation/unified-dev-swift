import Testing
import Foundation
@testable import Core

@Suite("Claude commands and output styles follow the account", .scratchDirectory)
struct ClaudeAccountIndexTests {
    private func accountDirectory() -> String {
        TestScratch.unique("account")
    }

    private func writeAccountPlugin(_ tree: SlashCommandTests.Tree, account: String) throws {
        let root = "\(account)/plugins/cache/lab/1.0.0"
        try tree.write("\(root)/.claude-plugin/plugin.json", #"{"name": "lab"}"#, under: "/")
        try tree.write("\(root)/skills/probe/SKILL.md", "---\nname: probe\ndescription: Lab probe\n---\n", under: "/")
        try tree.write("\(account)/settings.json", #"{"enabledPlugins": {"lab@market": true}}"#, under: "/")
        try tree.write(
            "\(account)/plugins/installed_plugins.json",
            #"{"version": 2, "plugins": {"lab@market": [{"scope": "user", "installPath": "\#(root)"}]}}"#,
            under: "/"
        )
    }

    @Test func commandsSkillsAndPluginsComeFromTheAccountDirectoryAndNotFromTheHome() throws {
        let tree = try SlashCommandTests.Tree()
        let account = accountDirectory()
        try tree.write(".claude/commands/personal-only.md", "---\ndescription: Home\n---\n")
        try tree.skill(".claude/skills/personal-skill", name: "personal-skill", description: "Home")
        try tree.write("commands/work-only.md", "---\ndescription: Account\n---\n", under: account)
        try tree.skill("skills/work-skill", name: "work-skill", description: "Account", under: account)
        try writeAccountPlugin(tree, account: account)

        let names = SlashCommandIndex.discover(home: tree.home, project: tree.project, claudeHome: account).map(\.name)

        #expect(names.contains("work-only"))
        #expect(names.contains("work-skill"))
        #expect(names.contains("lab:probe"))
        #expect(!names.contains("personal-only"))
        #expect(!names.contains("personal-skill"))
    }

    @Test func withoutAnAccountTheHomeDirectoryIsStillRead() throws {
        let tree = try SlashCommandTests.Tree()
        try tree.write(".claude/commands/personal-only.md", "---\ndescription: Home\n---\n")

        #expect(tree.names().contains("personal-only"))
    }

    @Test func aPluginEnabledOnlyInTheHomeSettingsIsNotOfferedUnderAnAccount() throws {
        let tree = try SlashCommandTests.Tree()
        let account = accountDirectory()
        try tree.write(".claude/settings.json", #"{"enabledPlugins": {"lab@market": true}}"#)
        try tree.write(
            ".claude/plugins/installed_plugins.json",
            #"{"version": 2, "plugins": {"lab@market": [{"scope": "user", "installPath": "\#(tree.home)/p"}]}}"#
        )
        try tree.skill("p/skills/hidden", name: "hidden", description: "Home plugin")
        try tree.write("p/.claude-plugin/plugin.json", #"{"name": "lab"}"#)
        try tree.write("commands/anything.md", "---\ndescription: x\n---\n", under: account)

        let names = SlashCommandIndex.discover(home: tree.home, project: tree.project, claudeHome: account).map(\.name)

        #expect(!names.contains("lab:hidden"))
    }

    @Test func outputStylesComeFromTheAccountDirectoryAndNotFromTheHome() throws {
        let tree = try SlashCommandTests.Tree()
        let account = accountDirectory()
        try tree.write(".claude/output-styles/home.md", "---\nname: HomeStyle\ndescription: Home\n---\n")
        try tree.write("output-styles/work.md", "---\nname: WorkStyle\ndescription: Account\n---\n", under: account)

        let names = OutputStyleIndex.discover(home: tree.home, project: tree.project, claudeHome: account).map(\.name)

        #expect(names.contains("WorkStyle"))
        #expect(!names.contains("HomeStyle"))
    }
}
