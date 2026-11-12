import Testing
@testable import Core

@Suite struct ProviderIdlePolicyTests {
    @Test func nothingStoredEvictsAfterThirtyMinutes() {
        #expect(ProviderIdlePolicy.minutes(stored: nil) == 30)
        #expect(ProviderIdlePolicy.duration(stored: nil) == .seconds(1_800))
    }

    @Test func aStoredZeroMeansNever() {
        #expect(ProviderIdlePolicy.minutes(stored: "0") == 0)
        #expect(ProviderIdlePolicy.duration(stored: "0") == nil)
    }

    @Test("an invalid stored value means never", arguments: ["nonsense", "-1", "9999999", "", "45"])
    func anInvalidStoredValueMeansNever(stored: String) {
        #expect(ProviderIdlePolicy.minutes(stored: stored) == 0)
        #expect(ProviderIdlePolicy.duration(stored: stored) == nil)
    }

    @Test("every other stored choice keeps its meaning", arguments: [15, 30, 60, 120])
    func aStoredChoiceKeepsItsMeaning(minutes: Int) {
        #expect(ProviderIdlePolicy.minutes(stored: String(minutes)) == minutes)
        #expect(ProviderIdlePolicy.duration(stored: String(minutes)) == .seconds(minutes * 60))
    }
}
