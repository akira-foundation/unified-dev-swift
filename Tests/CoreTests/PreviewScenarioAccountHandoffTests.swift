import Foundation
import Testing
@testable import Core

@Suite("A preview scenario that moves a chat to another account of the same agent")
struct PreviewScenarioAccountHandoffTests {
    private func refusal(_ json: String) -> String {
        do {
            _ = try PreviewScenario.read(Data(json.utf8))
            return ""
        } catch {
            return String(describing: error)
        }
    }

    private func scenario(_ handoff: String, accounts: String = "") -> String {
        """
        {"accounts":[\(accounts)],"projects":[{"name":"a","workspaces":[{"name":"w","branch":"w","chats":[
          {"title":"Plan","agent":"claudeCode","model":"opus","messages":[
            {"from":"user","text":"Go"},{"from":"agent","handoff":\(handoff)}]}]}]}]}
        """
    }

    private let client = #"{"provider":"claudeCode","email":"ada@client.example","label":"client"}"#

    @Test func aMoveToADeclaredAccountOfTheSameAgentIsAccepted() throws {
        let read = try PreviewScenario.read(Data(scenario(
            #"{"agent":"claudeCode","model":"opus","account":"client"}"#, accounts: client
        ).utf8))

        #expect(read.projects[0].workspaces[0].chats[0].messages[1].handoff?.account == "client")
    }

    @Test func aMoveToAnAccountTheScenarioDoesNotDeclareIsRefused() {
        #expect(refusal(scenario(#"{"agent":"claudeCode","model":"opus","account":"client"}"#))
            .contains("which the scenario does not declare"))
    }

    @Test func aMoveToTheAccountTheChatAlreadyRunsUnderIsRefused() {
        let twice = """
        {"accounts":[\(client)],"projects":[{"name":"a","workspaces":[{"name":"w","branch":"w","chats":[
          {"title":"Plan","agent":"claudeCode","model":"opus","messages":[
            {"from":"user","text":"Go"},
            {"from":"agent","handoff":{"agent":"claudeCode","model":"opus","account":"client"}},
            {"from":"agent","handoff":{"agent":"claudeCode","model":"opus","account":"client"}}]}]}]}]}
        """

        #expect(refusal(twice).contains("already runs under"))
    }

    @Test func theTargetCarriesTheAccountAndTheNameTheDividerShows() throws {
        let account = PreviewScenario.Account(provider: .claudeCode, email: "ada@client.example", label: "client")
        let target = PreviewScenarioSeeder.target(
            of: PreviewScenario.Handoff(agent: .claudeCode, model: "opus", account: "client"), among: [account]
        )

        #expect(target.accountID == account.id)
        #expect(target.accountName == "ada@client.example")
    }

    @Test func aMoveWithNoAccountKeepsNone() {
        let target = PreviewScenarioSeeder.target(
            of: PreviewScenario.Handoff(agent: .codex, model: "gpt-5"), among: []
        )

        #expect(target.accountID == nil)
        #expect(target.accountName == nil)
    }
}

@Suite("The scenario the account switch walkthrough uses")
struct PreviewScenarioAccountHandoffFileTests {
    @Test func itHoldsAMoveBetweenTwoAccountsOfOneAgent() throws {
        let root = URL(fileURLWithPath: #filePath)
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path
        let read = try PreviewScenario.read(path: root + "/Tools/scenarios/switch-account-in-chat.json")
        let chats = read.projects.flatMap(\.workspaces).flatMap(\.chats)
        let moved = chats.first { chat in
            chat.messages.contains { $0.handoff?.agent == chat.agent && $0.handoff?.account != nil }
        }

        #expect(moved != nil)
    }
}
