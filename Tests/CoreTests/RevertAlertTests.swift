import Testing
@testable import Core

@Suite("What a revert that did not happen says")
struct RevertAlertTests {
    @Test("a reverted file raises no alert")
    func revertedIsQuiet() {
        #expect(RevertAlert(.reverted, filename: "Handler.php") == nil)
    }

    @Test("a refusal does not claim the revert was tried")
    func refusalHasATitleOfItsOwn() {
        let alert = RevertAlert(.refused(FileBarControls.revertWhileAgentWorks), filename: "Handler.php")

        #expect(alert?.title == "Nothing was reverted")
        #expect(alert?.title.contains("Could not") == false)
        #expect(alert?.message == FileBarControls.revertWhileAgentWorks)
    }

    @Test("a failure says it failed and carries git's own words")
    func failureCarriesGit() {
        let git = "error: unable to unlink old 'Handler.php': Permission denied"
        let alert = RevertAlert(.failed(git), filename: "Handler.php")

        #expect(alert?.title == "Could not revert Handler.php")
        #expect(alert?.message == git)
    }

    @Test("a failure git gave no words for still says something")
    func silentFailure() {
        #expect(RevertAlert(.failed(""), filename: "Handler.php")?.message == "Git gave no reason")
    }

    @Test("every title is capitalised and none ends in a full stop")
    func theRegisterIsRight() {
        let outcomes: [RevertOutcome] = [.refused(FileBarControls.revertWhileAgentWorks), .failed("x")]
        for outcome in outcomes {
            let alert = RevertAlert(outcome, filename: "handler.php")
            #expect(alert?.title.first?.isUppercase == true)
            #expect(alert?.title.hasSuffix(".") == false)
        }
        #expect(RevertAlert(.refused(FileBarControls.revertWhileAgentWorks), filename: "a")?.message.hasSuffix(".") == false)
    }
}
