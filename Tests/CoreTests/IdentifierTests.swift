import Foundation
import Testing
@testable import Core

@Suite("Typed identifiers")
struct IdentifierTests {
    @Test("an identifier encodes as a bare JSON string, not as an object")
    func encodesAsABareString() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        #expect(String(decoding: try encoder.encode(WorkspaceID("w1")), as: UTF8.self) == "\"w1\"")
        #expect(String(decoding: try encoder.encode(SessionID("s1")), as: UTF8.self) == "\"s1\"")
        #expect(String(decoding: try encoder.encode(RepoID("r1")), as: UTF8.self) == "\"r1\"")
    }

    @Test("a payload stored when ids were strings decodes into the typed shape")
    func oldPayloadsStillDecode() throws {
        struct Tab: Codable, Equatable {
            var id: String
            var workspaceID: WorkspaceID
            var kind: String
            var title: String
            var url: String
            var path: String
        }

        let stored = #"""
        {"id":"t1","kind":"terminal","path":"","title":"Terminal","url":"","workspaceID":"9d4b0f1e-1111-2222-3333-444455556666"}
        """#.trimmingCharacters(in: .whitespacesAndNewlines)

        let tab = try JSONDecoder().decode(Tab.self, from: Data(stored.utf8))
        #expect(tab.workspaceID == WorkspaceID("9d4b0f1e-1111-2222-3333-444455556666"))

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        #expect(String(decoding: try encoder.encode(tab), as: UTF8.self) == stored)
    }

    @Test("an identifier interpolates as its raw value, so stored keys do not move")
    func interpolatesAsTheRawValue() {
        let workspace = WorkspaceID("w1")

        #expect("\(workspace)" == "w1")
        #expect(OpenInPreferences.key(forRepo: RepoID("r1")) == "openIn.lastUsed.r1")
        #expect(ComposerControls.fastModeKey(sessionID: SessionID("s1")) == "session.s1.fastMode")
    }

    @Test("a typed identifier binds as the text it always was")
    func bindsAsText() {
        #expect(SQLValue.text(WorkspaceID("w1")) == .text("w1"))
        #expect(SQLValue.text(SessionID("s1")) == .text("s1"))

        #expect(SQLValue.text(WorkspaceID?.none) == .null)
        #expect(SQLValue.text(WorkspaceID?.some(WorkspaceID("w1"))) == .text("w1"))
    }
}
