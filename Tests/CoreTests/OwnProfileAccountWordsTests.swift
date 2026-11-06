import Testing
import Foundation
@testable import Core

@Suite("What a profile with accounts of its own says when nothing would start")
struct OwnProfileAccountWordsTests {
    private var standings: [AgentAccountStanding] {
        [
            AccountFixture.standing(AccountFixture.defaultClaude, email: "me@home.com"),
            AccountFixture.standing(AccountFixture.work, email: "me@client.com"),
        ]
    }

    private func group(
        _ scope: AgentAccountOptions.Scope, _ choices: AgentAccountChoices, outsideProfile: Bool = true
    ) throws -> AgentAccountOptions.Group {
        let made = AgentAccountOptions.make(
            scope: scope, choices: choices, standings: standings, outsideProfile: outsideProfile
        )
        return try #require(made.groups.first { $0.provider == .claudeCode })
    }

    @Test("a project with nothing chosen offers no account and warns that nothing starts")
    func projectWithNothingChosen() throws {
        let made = try group(.project, AgentAccountChoices())

        #expect(made.inherit.title == "No account")
        #expect(made.note == "No workspace or chat in this project starts Claude Code until an account is chosen.")
        #expect(made.warns)
    }

    @Test("a project whose choice is gone, with no profile default, says nothing starts")
    func projectChoiceGone() throws {
        let made = try group(.project, AgentAccountChoices(project: [.claudeCode: AgentAccountID("gone")]))

        #expect(made.note == "The account chosen for Claude Code in this project is not available, "
            + "so no workspace or chat starts Claude Code.")
        #expect(made.warns)
    }

    @Test("a project following a profile default that is gone says nothing starts")
    func profileDefaultGone() throws {
        let made = try group(.project, AgentAccountChoices(profile: [.claudeCode: AgentAccountID("gone")]))

        #expect(made.inherit.title == "Same as profile")
        #expect(made.note == "The account chosen for Claude Code in the profile is not available, "
            + "so no workspace or chat starts Claude Code.")
        #expect(made.warns)
    }

    @Test("a profile whose default is gone says its projects do not start the agent")
    func profileOwnDefaultGone() throws {
        let made = try group(.profile, AgentAccountChoices(profile: [.claudeCode: AgentAccountID("gone")]))

        #expect(made.note == "The account chosen for Claude Code in this profile is not available, "
            + "so its projects do not start Claude Code until one is chosen.")
        #expect(made.warns)
    }

    @Test("Unified keeps naming the default account where an own profile names none")
    func unifiedKeepsTheDefault() throws {
        let made = try group(.project, AgentAccountChoices(), outsideProfile: false)

        #expect(made.inherit.title == "Default account")
        #expect(!made.warns)
    }

    @Test("with nothing to offer, an own profile says no agent that needs an account starts")
    func nothingToOffer() {
        let only = [AccountFixture.standing(AccountFixture.defaultClaude, email: "me@home.com")]
        let profile = AgentAccountOptions.make(
            scope: .profile, choices: AgentAccountChoices(), standings: only, outsideProfile: true
        )
        let project = AgentAccountOptions.make(
            scope: .project, choices: AgentAccountChoices(), standings: only, outsideProfile: true
        )

        #expect(profile.footer == "No project in this profile starts an agent that needs an account until it has one. "
            + AgentAccountOptions.addAnAccount)
        #expect(project.footer == "No workspace or chat in this project starts an agent that needs an account "
            + "until it has one. " + AgentAccountOptions.addAnAccount)
    }
}
