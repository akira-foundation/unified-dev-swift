import Foundation
import Testing
@testable import Core

@Suite("Installed agent kinds")
struct InstalledAgentKindsTests {
    @Test("counts an agent the user pointed at a path of their own")
    func honoursAnOverride() async {
        let found = await AgentCatalog.installedKinds(overrides: [.codex: "/bin/ls"])

        #expect(found.contains(.codex))
    }

    @Test("does not count an override that points at nothing")
    func ignoresABrokenOverride() async {
        let found = await AgentCatalog.installedKinds(overrides: [.cursor: "/nowhere/at/all/cursor-agent"])

        #expect(!found.contains(.cursor))
    }

    @Test("answers in the catalogue's own order")
    func isOrdered() async {
        let found = await AgentCatalog.installedKinds(overrides: [.codex: "/bin/ls", .openCode: "/bin/ls"])
        let ordered = AgentKind.allCases.filter(found.contains)

        #expect(found == ordered)
    }

    @Test("files an executable path under the key the Agents pane uses")
    func settingKeySpelling() {
        #expect(AgentCatalog.executablePathSettingKey(.claudeCode) == "agent.claudeCode.executablePath")
        #expect(AgentCatalog.executablePathSettingKey(.codex) == "agent.codex.executablePath")
    }
}
