import Testing
import Foundation
@testable import Core

@Suite("Claude plan from the rate limit tier")
struct ClaudePlanTierTests {
    private let now = Date(timeIntervalSince1970: 1_791_676_800)

    @Test("a max_20x tier is Ultra and a max_5x tier is Max, whatever the subscription type says")
    func claudePlanFollowsTheTier() {
        #expect(AgentAccountReader.claudePlan("max", rateLimitTier: "default_claude_max_20x") == "Ultra")
        #expect(AgentAccountReader.claudePlan("max", rateLimitTier: "default_claude_max_5x") == "Max")
        #expect(AgentAccountReader.claudePlan("ultra", rateLimitTier: nil) == "Ultra")
        #expect(AgentAccountReader.claudePlan("ULTRA", rateLimitTier: "default_claude_max_5x") == "Ultra")
    }

    @Test("an unknown or missing tier keeps the title-cased subscription type")
    func claudePlanFallsBack() {
        #expect(AgentAccountReader.claudePlan("max", rateLimitTier: nil) == "Max")
        #expect(AgentAccountReader.claudePlan("max", rateLimitTier: "") == "Max")
        #expect(AgentAccountReader.claudePlan("pro", rateLimitTier: "default_claude_ai") == "Pro")
        #expect(AgentAccountReader.claudePlan("team", rateLimitTier: "default_raven") == "Team")
        #expect(AgentAccountReader.claudePlan("", rateLimitTier: "default_claude_max_20x") == "Ultra")
    }

    @Test("get_usage carries the tier through to the plan")
    func claudePlanFromUsageTier() {
        let answer = """
        {"session":{"total_cost_usd":0},"subscription_type":"max","rate_limit_tier":"default_claude_max_20x",\
        "rate_limits_available":true,"rate_limits":{}}
        """
        #expect(AgentAccountReader.account(from: Data(answer.utf8), at: now)?.plan == "Ultra")
    }
}
