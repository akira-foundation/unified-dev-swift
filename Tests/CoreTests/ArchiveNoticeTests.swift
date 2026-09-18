import Foundation
import Testing
@testable import Core

@Suite("What an archive says afterwards")
struct ArchiveNoticeTests {
    private func command(_ description: String) -> Subagent {
        Subagent(
            id: SubagentID(UUID().uuidString), description: description,
            taskType: "local_bash", state: .running
        )
    }

    @Test("an archive that stopped nothing and kept nothing says nothing")
    func quietArchive() {
        #expect(ArchiveNotice.after(archiving: "Docs", preservedFolderPath: nil, stopping: []) == nil)
    }

    @Test("an archive names the background commands it stopped, as information, for a moment")
    func namesTheStoppedCommands() throws {
        let notice = try #require(ArchiveNotice.after(
            archiving: "Docs", preservedFolderPath: nil, stopping: [command("Serve on 127.0.0.1:8018")]
        ))

        #expect(notice.message == "Docs was archived. It stopped a background command: Serve on 127.0.0.1:8018.")
        #expect(notice.tone == .information)
        #expect(notice.dismissal == .afterReading)
    }

    @Test("the notice splits between what happened and what was stopped")
    func splitsAfterTheFact() throws {
        let notice = try #require(ArchiveNotice.after(
            archiving: "Docs", preservedFolderPath: nil, stopping: [command("Serve on 127.0.0.1:8018")]
        ))

        #expect(notice.text.fact.map(\.text).joined() == "Docs was archived.")
        #expect(notice.text.reason.map(\.text).joined()
            == "It stopped a background command: Serve on 127.0.0.1:8018.")
    }

    @Test("a kept folder is the news, a warning that stays until dismissed, and outranks the stopped commands")
    func keptFolderComesFirst() throws {
        let notice = try #require(ArchiveNotice.after(
            archiving: "Docs", preservedFolderPath: "/tmp/docs", stopping: [command("Serve")]
        ))

        #expect(notice.message.hasPrefix("Docs was archived. Its folder at `/tmp/docs` and its branch"))
        #expect(notice.message.contains("no longer recognises the folder as a worktree"))
        #expect(!notice.message.contains("Serve"))
        #expect(notice.tone == .warning)
        #expect(notice.dismissal == .untilDismissed)
    }
}
