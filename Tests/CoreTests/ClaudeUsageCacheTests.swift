import Foundation
import Testing
@testable import Core

@Suite("Claude usage cache")
struct ClaudeUsageCacheTests {
    private let fetchedAtMs = 1_790_859_223_675.0
    private var fetchedAt: Date { Date(timeIntervalSince1970: fetchedAtMs / 1000) }

    private let askID = "unifieddev-usage-1"

    private let recordedLine = """
        {"type":"control_response","response":{"request_id":"unifieddev-usage-1","subtype":"success",\
        "response":{"session":{"total_cost_usd":0.4},"subscription_type":null,\
        "rate_limits_available":false,"rate_limits":null,"behaviors":null}}}
        """

    private func emptyAnswer() throws -> Data {
        try #require(ClaudeCodeQuotaSource.answer(in: recordedLine, to: askID))
    }

    private func account(fetchedAtMs: Double? = 1_790_859_223_675, extras: String = "") -> Data {
        let stamp = fetchedAtMs.map { "\"fetchedAtMs\":\($0)," } ?? ""
        return Data("""
            {"numStartups":7,
             "cachedUsageUtilization":{\(stamp)
               "utilization":{
                 "five_hour":{"utilization":33,"resets_at":"2026-10-01T18:49:59.582059+00:00"},
                 "seven_day":{"utilization":9,"resets_at":"2026-10-07T21:59:59.582080+00:00"},
                 "seven_day_opus":null\(extras)}}}
            """.utf8)
    }

    private func quotas(_ reading: ClaudeUsageCache.Reading) -> [String: AgentQuota] {
        let read = AgentQuotaAdapters.quotas(fromRateLimitEvent: reading.payload, at: Date())
        return Dictionary(read.map { ($0.window.key, $0) }, uniquingKeysWith: { first, _ in first })
    }

    @Test("the answer the CLI actually gives carries no limits")
    func recordedEmptyAnswer() throws {
        let payload = try emptyAnswer()
        #expect(!ClaudeCodeUsageAdapter.carriesLimits(payload))
        #expect(AgentQuotaAdapters.quotas(fromRateLimitEvent: payload, at: fetchedAt).isEmpty)
    }

    @Test("the CLI saying its limits do not apply is a different answer from no answer")
    func declinedLimits() throws {
        #expect(ClaudeCodeUsageAdapter.declinesLimits(try emptyAnswer()))
        #expect(!ClaudeCodeUsageAdapter.declinesLimits(nil))
        #expect(!ClaudeCodeUsageAdapter.declinesLimits(Data("not json".utf8)))
        #expect(!ClaudeCodeUsageAdapter.declinesLimits(Data(#"{"session":{}}"#.utf8)))

        let reading = try #require(ClaudeUsageCache.reading(from: account(), at: fetchedAt))
        let overlaid = try #require(ClaudeCodeQuotaSource.overlaid(emptyAnswer(), with: reading.payload))
        #expect(!ClaudeCodeUsageAdapter.declinesLimits(overlaid))
    }

    @Test("an answer that says it has limits and carries none is not one we keep")
    func limitsHaveToBeThere() {
        let claimed = Data(#"{"rate_limits_available":true,"rate_limits":null}"#.utf8)
        let real = Data(#"{"rate_limits_available":true,"rate_limits":{"five_hour":{"utilization":4}}}"#.utf8)
        #expect(!ClaudeCodeUsageAdapter.carriesLimits(claimed))
        #expect(ClaudeCodeUsageAdapter.carriesLimits(real))
        #expect(!ClaudeCodeUsageAdapter.carriesLimits(nil))
        #expect(!ClaudeCodeUsageAdapter.carriesLimits(Data("not json".utf8)))
    }

    @Test("a fresh cache gives the five hour and seven day windows, read when the CLI read them")
    func freshCache() throws {
        let now = fetchedAt.addingTimeInterval(600)
        let reading = try #require(ClaudeUsageCache.reading(from: account(), at: now))
        #expect(reading.fetchedAt == fetchedAt)

        let found = quotas(reading)
        #expect(found["five_hour"]?.measure == .fraction(0.33))
        #expect(found["seven_day"]?.measure == .fraction(0.09))
        #expect(found["five_hour"]?.observedAt == fetchedAt)
        #expect(found["seven_day"]?.observedAt == fetchedAt)
    }

    @Test("a model window and a spend window are dated from the reading too, not from now")
    func everyWindowCarriesTheReadingTime() throws {
        let extras = """
            ,"model_scoped":[{"display_name":"Fable","utilization":12,\
            "resets_at":"2026-10-07T21:59:59.582080+00:00"}],\
            "extra_usage":{"is_enabled":true,"used_credits":9710,"monthly_limit":25000,"currency":"USD"}
            """
        let reading = try #require(ClaudeUsageCache.reading(from: account(extras: extras), at: fetchedAt))

        let found = quotas(reading)
        #expect(found["seven_day_model_fable"]?.observedAt == fetchedAt)
        #expect(found["extra_usage"]?.observedAt == fetchedAt)
        #expect(found["extra_usage"]?.measure == .counted(used: 97.1, limit: 250, unit: "USD"))
    }

    @Test("a cache is read for an hour after it was taken, and not a minute longer")
    func theHourOfTrust() {
        #expect(ClaudeUsageCache.trusted == 3600)
        #expect(ClaudeUsageCache.reading(from: account(), at: fetchedAt.addingTimeInterval(3540)) != nil)
        #expect(ClaudeUsageCache.reading(from: account(), at: fetchedAt.addingTimeInterval(3660)) == nil)
        #expect(!ClaudeUsageCache.isTrusted(fetchedAt: fetchedAt, at: fetchedAt.addingTimeInterval(3601)))
        #expect(ClaudeUsageCache.isTrusted(fetchedAt: fetchedAt, at: fetchedAt.addingTimeInterval(3600)))
    }

    @Test("a cache stamped ahead of this Mac's clock is refused, give or take five seconds")
    func futureCache() {
        #expect(ClaudeUsageCache.grace == 5)
        #expect(ClaudeUsageCache.isTrusted(fetchedAt: fetchedAt, at: fetchedAt.addingTimeInterval(-5)))
        #expect(!ClaudeUsageCache.isTrusted(fetchedAt: fetchedAt, at: fetchedAt.addingTimeInterval(-6)))
        #expect(ClaudeUsageCache.reading(from: account(), at: fetchedAt.addingTimeInterval(-6)) == nil)
        #expect(ClaudeUsageCache.reading(from: account(), at: fetchedAt.addingTimeInterval(-60)) == nil)
    }

    @Test("when the stamp is too old to read, it still says when the CLI last reported")
    func stampOutlivesTheReading() {
        let later = fetchedAt.addingTimeInterval(ClaudeUsageCache.trusted * 48)
        #expect(ClaudeUsageCache.fetchedAt(in: account(), at: later) == fetchedAt)
        #expect(ClaudeUsageCache.fetchedAt(in: Data(#"{"numStartups":7}"#.utf8), at: later) == nil)
        #expect(ClaudeUsageCache.fetchedAt(in: nil, at: later) == nil)
    }

    @Test("a stamp that could not be a reading is not one, and never reaches a sentence")
    func unreadableStamp() {
        let now = fetchedAt
        for broken in ["-1e24", "1e24", "-1"] {
            let file = Data("""
                {"cachedUsageUtilization":{"fetchedAtMs":\(broken),"utilization":{"five_hour":{"utilization":3}}}}
                """.utf8)
            #expect(ClaudeUsageCache.fetchedAt(in: file, at: now) == nil)
            #expect(ClaudeUsageCache.reading(from: file, at: now) == nil)
        }
    }

    @Test("an answer whose limits are an empty object carries none")
    func emptyLimitsAreNoLimits() {
        #expect(!ClaudeCodeUsageAdapter.carriesLimits(Data(#"{"rate_limits_available":true,"rate_limits":{}}"#.utf8)))
    }

    @Test("a cache with no stamp, no file, or nothing readable gives nothing")
    func nothingToRead() {
        let now = fetchedAt
        #expect(ClaudeUsageCache.reading(from: account(fetchedAtMs: nil), at: now) == nil)
        #expect(ClaudeUsageCache.reading(from: Data(#"{"numStartups":7}"#.utf8), at: now) == nil)
        #expect(ClaudeUsageCache.reading(from: Data("not json".utf8), at: now) == nil)
        #expect(ClaudeUsageCache.reading(from: nil, at: now) == nil)
    }

    @Test("the cached limits are laid over the answer, which keeps its session and its plan")
    func overlaidOnTheAnswer() throws {
        let reading = try #require(ClaudeUsageCache.reading(from: account(), at: fetchedAt))
        let overlaid = try #require(ClaudeCodeQuotaSource.overlaid(emptyAnswer(), with: reading.payload))
        let json = try #require(JSONValue.parse(overlaid))

        #expect(json["rate_limits_available"]?.boolValue == true)
        #expect(json["session"]?["total_cost_usd"]?.doubleValue == 0.4)
        #expect(ClaudeCodeUsageAdapter.carriesLimits(overlaid))
    }

    @Test("with no answer to lay them over there is nothing to overlay")
    func nothingToOverlay() throws {
        let reading = try #require(ClaudeUsageCache.reading(from: account(), at: fetchedAt))
        #expect(ClaudeCodeQuotaSource.overlaid(nil, with: reading.payload) == nil)
        #expect(ClaudeCodeQuotaSource.overlaid(Data("[]".utf8), with: reading.payload) == nil)
    }
}
