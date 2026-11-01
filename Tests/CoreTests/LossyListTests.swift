import Testing
import Foundation
@testable import Core

@Suite("Lossy list")
struct LossyListTests {
    struct Item: Codable, Equatable {
        enum Kind: String, Codable { case a, b }
        var kind: Kind
        var name: String
    }

    private func decode(_ json: String) -> [Item]? {
        LossyList.decode(Item.self, from: Data(json.utf8))
    }

    @Test("an element of an unknown kind is skipped and the rest kept")
    func unknownKindIsSkipped() {
        let items = decode(#"[{"kind":"a","name":"1"},{"kind":"zzz","name":"2"},{"kind":"b","name":"3"}]"#)
        #expect(items == [Item(kind: .a, name: "1"), Item(kind: .b, name: "3")])
    }

    @Test("a malformed element is skipped")
    func malformedElementIsSkipped() {
        let items = decode(#"[{"kind":"a","name":"1"},{"kind":"b"},{"kind":"b","name":"3"}]"#)
        #expect(items == [Item(kind: .a, name: "1"), Item(kind: .b, name: "3")])
    }

    @Test("data that is not an array is nil")
    func notAnArrayIsNil() {
        #expect(decode(#"{"kind":"a"}"#) == nil)
        #expect(LossyList.decode(Item.self, from: Data([0xFF, 0x00, 0x7B])) == nil)
    }

    @Test("an empty array is empty, not nil")
    func emptyArrayIsEmpty() {
        #expect(decode("[]") == [])
    }
}
