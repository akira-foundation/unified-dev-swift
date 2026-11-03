import Testing
@testable import Core

@Suite("UpdateRestartWait")
struct UpdateRestartWaitTests {
    @Test func theWaitExpiresAtTheLimit() {
        var wait = UpdateRestartWait()
        let early = wait.tick(seconds: UpdateRestartWait.limit - 1, isAsking: false)
        let late = wait.tick(seconds: 1, isAsking: false)

        #expect(!early)
        #expect(late)
    }

    @Test func aQuestionOnScreenPausesTheWait() {
        var wait = UpdateRestartWait()
        let asking = wait.tick(seconds: UpdateRestartWait.limit * 10, isAsking: true)
        let afterwards = wait.tick(seconds: UpdateRestartWait.limit - 1, isAsking: false)

        #expect(!asking)
        #expect(!afterwards)
    }
}
