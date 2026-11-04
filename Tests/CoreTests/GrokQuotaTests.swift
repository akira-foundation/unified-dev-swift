import Testing
import Foundation
@testable import Core

@Suite("Grok quota")
struct GrokQuotaTests {
    private static let now = Date(timeIntervalSince1970: 1_793_790_000)

    private static let billing = """
    {"config":{"creditUsagePercent":100.0,"currentPeriod":{"type":"USAGE_PERIOD_TYPE_WEEKLY",\
    "start":"2026-11-01T13:01:35.239+00:00","end":"2026-11-08T13:01:35.239+00:00"},\
    "prepaidBalance":{"val":0},"isUnifiedBillingUser":true,\
    "billingPeriodStart":"2026-11-01T13:01:35.239+00:00","billingPeriodEnd":"2026-11-08T13:01:35.239+00:00"},\
    "subscription_tier":"SuperGrok Lite"}
    """

    private static func reading(_ text: String = billing) -> [AgentQuota] {
        AgentQuotaAdapters.quotas(fromRateLimitEvent: Data(text.utf8), at: now)
    }

    @Test("the billing answer reads as one weekly window, spent, resetting when the period ends")
    func readsTheWeeklyPeriod() throws {
        let quota = try #require(Self.reading().first)
        let end = try #require(ClaudeCodeUsageAdapter.date(fromISO: "2026-11-08T13:01:35.239+00:00"))

        #expect(Self.reading().count == 1)
        #expect(quota.provider == .grok)
        #expect(quota.window.key == "weekly")
        #expect(quota.window.label == "Weekly")
        #expect(quota.window.duration == 604_800)
        #expect(quota.fraction == 1)
        #expect(quota.resetsAt == end)
        #expect(UsageCatalogue.kind(of: quota) == .weekly)
    }

    @Test("a part spent is a fraction of the whole")
    func readsAPartialSpend() throws {
        let partial = Self.billing.replacingOccurrences(of: "100.0", with: "37.5")
        #expect(try #require(Self.reading(partial).first).fraction == 0.375)
    }

    @Test("a period with no type is named after its length")
    func namesAnUntypedPeriodByItsLength() throws {
        let untyped = Self.billing.replacingOccurrences(of: #""type":"USAGE_PERIOD_TYPE_WEEKLY","#, with: "")
        let quota = try #require(Self.reading(untyped).first)

        #expect(quota.window.key == "credits")
        #expect(quota.window.label == "Week")
    }

    @Test("an answer with no usage figure is not a Grok reading")
    func ignoresAnAnswerWithoutAFigure() {
        #expect(Self.reading(#"{"config":{"prepaidBalance":{"val":0}}}"#).isEmpty)
        #expect(Self.reading(#"{"rateLimits":{"primary":{"usedPercent":4}}}"#).allSatisfy { $0.provider != .grok })
    }

    @Test("the subscription tier is the plan")
    func readsThePlan() {
        let account = GrokQuotaSource().account(from: Data(Self.billing.utf8), at: Self.now)

        #expect(account?.provider == .grok)
        #expect(account?.plan == "SuperGrok Lite")
    }

    @Test("Grok now counts as an agent that reports usage")
    func publishesUsage() {
        #expect(AgentKind.grok.publishesUsage)
        #expect(UsageLayout.defaultProviderOrder.contains(.grok))
    }

    @Test("the source asks Grok's billing extension and hands back what it answers", .timeLimit(.minutes(1)))
    func asksTheBillingExtension() async throws {
        let box = ProcessBox()
        let answer = try #require(JSONValue.parse(Data(Self.billing.utf8)))
        box.reply(to: GrokQuotaSource.method, with: answer)
        let source = GrokQuotaSource(environment: [:], makeProcess: box.factory)

        let payload = try #require(await source.read())

        #expect(GrokQuotaSource.method == "_x.ai/billing")
        #expect(box.process.sentMethods.contains("_x.ai/billing"))
        #expect(box.process.launch.arguments.suffix(2) == ["--no-leader", "stdio"])
        #expect(AgentQuotaAdapters.quotas(fromRateLimitEvent: payload, at: Self.now).first?.fraction == 1)
    }

    @Test("the source asks under the account it was handed", .timeLimit(.minutes(1)))
    func asksUnderTheChosenAccount() async throws {
        let box = ProcessBox()
        let account = LaunchAccountFixture.workGrok
        let source = GrokQuotaSource(environment: LaunchAccountFixture.inherited, account: account, makeProcess: box.factory)

        _ = await source.read()

        #expect(box.process.launch.environment["GROK_HOME"] == account.directory.path)
    }

    @Test("the quota sources ask Grok under its own account")
    func registersGrokUnderItsAccount() {
        let sources = AgentQuotaSources.all(accounts: [.grok: LaunchAccountFixture.workGrok])
        #expect(sources.contains { type(of: $0).provider == .grok })
    }
}
