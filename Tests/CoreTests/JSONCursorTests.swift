import Testing
import Foundation
@testable import Core

private func read(_ json: String, _ body: (inout JSONCursor) -> Void) {
    let bytes = [UInt8](json.utf8)
    bytes.withUnsafeBufferPointer { buffer in
        var cursor = JSONCursor(buffer, from: 0, to: buffer.count)
        body(&cursor)
    }
}

private func value(of key: StaticString, in json: String) -> Int?? {
    var found: Int??
    read(json) { cursor in
        guard cursor.enterObject() else { return }
        while let name = cursor.nextKey() {
            if cursor.matches(name, key) {
                found = .some(cursor.integer())
                continue
            }
            cursor.skipValue()
        }
    }
    return found
}

private func text(of key: StaticString, in json: String) -> String?? {
    var found: String??
    read(json) { cursor in
        guard cursor.enterObject() else { return }
        while let name = cursor.nextKey() {
            if cursor.matches(name, key) {
                found = .some(cursor.text())
                continue
            }
            cursor.skipValue()
        }
    }
    return found
}

@Suite("JSON cursor")
struct JSONCursorTests {
    @Test("a whole number is read")
    func wholeNumber() {
        #expect(value(of: "n", in: #"{"n":1234}"#) == 1234)
        #expect(value(of: "n", in: #"{"n":-7}"#) == -7)
        #expect(value(of: "n", in: #"{"n":0}"#) == 0)
    }

    @Test("a number too big for an integer is refused rather than trapping")
    func overflow() {
        #expect(value(of: "n", in: #"{"n":99999999999999999999}"#) == .some(nil))
    }

    @Test("a number that is not whole is refused rather than truncated")
    func notWhole() {
        #expect(value(of: "n", in: #"{"n":2.5}"#) == .some(nil))
        #expect(value(of: "n", in: #"{"n":1e3}"#) == .some(nil))
    }

    @Test("an escaped character comes back as itself")
    func escapes() {
        #expect(text(of: "t", in: #"{"t":"a\"b"}"#) == "a\"b")
        #expect(text(of: "t", in: #"{"t":"a\\b"}"#) == "a\\b")
        #expect(text(of: "t", in: #"{"t":"a\nb"}"#) == "a\nb")
    }

    @Test("an escaped scalar comes back as the letter it names")
    func unicodeEscapes() {
        #expect(text(of: "t", in: #"{"t":"Lisbóa"}"#) == "Lisbóa")
        #expect(text(of: "t", in: #"{"t":"🚀"}"#) == "\u{1F680}")
    }

    @Test("a broken escape gives nothing rather than a wrong letter")
    func brokenEscape() {
        #expect(text(of: "t", in: #"{"t":"\u00"}"#) == .some(nil))
        #expect(text(of: "t", in: #"{"t":"\ud83d"}"#) == .some(nil))
    }

    @Test("a nested object or array is stepped over, not read into")
    func nesting() {
        let json = #"{"a":{"n":1,"deep":[1,{"n":2},"]"]},"n":3}"#
        #expect(value(of: "n", in: json) == 3)
    }

    @Test("a quoted brace inside a string does not end the object")
    func bracesInStrings() {
        #expect(value(of: "n", in: #"{"t":"}{\"n\":9}","n":4}"#) == 4)
    }

    @Test("a key that is not there is not found")
    func missingKey() {
        #expect(value(of: "n", in: #"{"m":1}"#) == nil)
    }

    @Test("an unterminated object does not run past its bytes")
    func unterminated() {
        #expect(value(of: "n", in: #"{"n":5"#) == 5)
        #expect(text(of: "t", in: #"{"t":"half"#) == .some("half"))
    }

    @Test("a string longer than the limit is dropped")
    func tooLong() {
        let fat = String(repeating: "x", count: JSONCursor.textLimit + 1)
        #expect(text(of: "t", in: "{\"t\":\"\(fat)\"}") == .some(nil))
    }
}
