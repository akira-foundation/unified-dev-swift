import Testing
import Foundation
@testable import Core

@Suite("Model prices")
struct ModelPricesTests {
    @Test("the table carries the date it was measured on")
    func measuredOn() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = calendar.dateComponents([.year, .month, .day], from: ModelPrices.measuredOn)
        #expect(parts.year == 2026)
        #expect(parts.month == 10)
        #expect(parts.day == 11)
    }

    @Test("a model id matches its own row before a shorter one")
    func longestPrefixWins() {
        let five = ModelPrices.pricing(for: "claude-opus-5", provider: .claudeCode)
        let fiveFive = ModelPrices.pricing(for: "claude-opus-5-5", provider: .claudeCode)
        #expect(five?.base.input == 5)
        #expect(fiveFive?.base.input == 4)
    }

    @Test("a dated model id falls back to the family it belongs to")
    func datedIdentifier() {
        let price = ModelPrices.pricing(for: "claude-haiku-4-5-20251001", provider: .claudeCode)
        #expect(price?.base.output == 5)
    }

    @Test("a dated id takes the longest row that is a prefix of it, not the shortest")
    func datedIdentifierPrefersTheLongerRow() {
        #expect(ModelPrices.pricing(for: "claude-opus-5-5-20260101", provider: .claudeCode)?.base.input == 4)
        #expect(ModelPrices.pricing(for: "claude-opus-5-20260101", provider: .claudeCode)?.base.input == 5)
    }

    @Test("an hour of cache costs more to write than five minutes")
    func cacheWriteWindows() throws {
        let price = try #require(ModelPrices.pricing(for: "claude-opus-5", provider: .claudeCode)).base
        let short = price.cost(of: TokenUsage(cacheWriteShort: 1_000_000))
        let long = price.cost(of: TokenUsage(cacheWriteLong: 1_000_000))
        #expect(short.cacheWrite == 6.25)
        #expect(long.cacheWrite == 10)
    }

    @Test("every column is priced on its own")
    func columns() throws {
        let spend = ModelPrices.spend(
            of: TokenUsage(
                freshInput: 1_000_000,
                cacheRead: 1_000_000,
                cacheWriteShort: 1_000_000,
                cacheWriteLong: 1_000_000,
                output: 1_000_000
            ),
            model: "claude-opus-5",
            provider: .claudeCode
        )
        #expect(spend.cost.freshInput == 5)
        #expect(spend.cost.cacheRead == 0.5)
        #expect(spend.cost.cacheWrite == 16.25)
        #expect(spend.cost.output == 25)
        #expect(spend.cost.total == 46.75)
        #expect(!spend.hasUnpricedTokens)
    }

    @Test("the cache saving is what the same tokens would have cost fresh")
    func saving() {
        let spend = ModelPrices.spend(
            of: TokenUsage(cacheRead: 2_000_000), model: "claude-opus-5", provider: .claudeCode
        )
        #expect(spend.cost.cacheRead == 1)
        #expect(spend.cost.saved == 9)
    }

    @Test("a model with no published price keeps its tokens and claims no cost")
    func unpricedModel() {
        let spend = ModelPrices.spend(
            of: TokenUsage(freshInput: 10, output: 20), model: "codex-auto-review", provider: .codex
        )
        #expect(spend.cost.total == 0)
        #expect(spend.usage.output == 20)
        #expect(spend.unpriced.output == 20)
        #expect(spend.hasUnpricedTokens)
    }

    @Test("Codex is not charged for writing to its cache")
    func openAICacheWrite() throws {
        let price = try #require(ModelPrices.pricing(for: "gpt-6-sol", provider: .codex)).base
        #expect(price.cacheWriteShort == 0)
        #expect(price.cacheRead == 0.20)
        #expect(price.input == 2)
    }

    @Test("a prompt over the short context limit is not priced from the short table")
    func longContextIsUnknown() throws {
        let pricing = try #require(ModelPrices.pricing(for: "gpt-6-sol", provider: .codex))
        #expect(pricing.price(forPrompt: ModelPrices.shortContextLimit) != nil)
        #expect(pricing.price(forPrompt: ModelPrices.shortContextLimit + 1) == nil)
    }

    @Test("a long Haiku prompt is priced from its own row")
    func haikuTier() throws {
        let pricing = try #require(ModelPrices.pricing(for: "claude-haiku-5-5", provider: .claudeCode))
        #expect(pricing.price(forPrompt: 100_000)?.output == 0.50)
        #expect(pricing.price(forPrompt: 100_001)?.output == 2.50)
    }

    @Test("a prompt over the short context limit is priced by nothing, through spend as well")
    func longContextSpend() {
        let spend = ModelPrices.spend(
            of: TokenUsage(freshInput: ModelPrices.shortContextLimit + 1, output: 1),
            model: "gpt-6-sol",
            provider: .codex
        )
        #expect(spend.hasUnpricedTokens)
        #expect(spend.cost.total == 0)
    }

    @Test("a long Haiku prompt is charged at its own rate, through spend as well")
    func haikuTierSpend() {
        let base = ModelPrices.spend(
            of: TokenUsage(freshInput: 100_000), model: "claude-haiku-5-5", provider: .claudeCode
        )
        let long = ModelPrices.spend(
            of: TokenUsage(freshInput: 100_001), model: "claude-haiku-5-5", provider: .claudeCode
        )
        #expect(abs(base.cost.freshInput - 0.01) < 0.000_001)
        #expect(long.cost.freshInput > base.cost.freshInput * 4)
        #expect(!long.hasUnpricedTokens)
    }

    @Test("the tier is decided per request, so two short prompts are not charged as one long one")
    func tierIsPerRequest() {
        let short = TokenUsage(freshInput: 60_000)
        #expect(ModelPrices.tier(for: "claude-haiku-5-5", provider: .claudeCode, prompt: short.prompt) == .base)
        let day = short + short
        #expect(ModelPrices.tier(for: "claude-haiku-5-5", provider: .claudeCode, prompt: day.prompt) == .longPrompt)
        let priced = ModelPrices.spend(
            of: day, model: "claude-haiku-5-5", provider: .claudeCode, tier: .base
        )
        #expect(abs(priced.cost.freshInput - 0.012) < 0.000_001)
    }

    @Test("a tier with no published rate reads as unpriced rather than as the base rate")
    func unpricedTier() throws {
        let pricing = try #require(ModelPrices.pricing(for: "gpt-6-sol", provider: .codex))
        #expect(pricing.tier(forPrompt: ModelPrices.shortContextLimit + 1) == .unpriced)
        #expect(pricing.price(.unpriced) == nil)
    }

    @Test("a provider that publishes no prices prices nothing")
    func providerWithoutTable() {
        #expect(ModelPrices.pricing(for: "grok-4", provider: .grok) == nil)
    }
}
