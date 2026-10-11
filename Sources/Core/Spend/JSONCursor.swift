import Foundation

public struct JSONCursor {
    public struct Range: Sendable, Equatable {
        public var start: Int
        public var count: Int
    }

    public static let textLimit = 1024

    let bytes: UnsafeBufferPointer<UInt8>
    let end: Int
    public private(set) var index: Int

    public init(_ bytes: UnsafeBufferPointer<UInt8>, from: Int, to: Int) {
        self.bytes = bytes
        self.index = from
        self.end = to
    }

    public var isAtEnd: Bool { index >= end }

    public mutating func enterObject() -> Bool {
        skipSpace()
        guard !isAtEnd, bytes[index] == UInt8(ascii: "{") else { return false }
        index += 1
        return true
    }

    public mutating func nextKey() -> Range? {
        skipSpace()
        while !isAtEnd, bytes[index] == UInt8(ascii: ",") {
            index += 1
            skipSpace()
        }
        guard !isAtEnd else { return nil }
        if bytes[index] == UInt8(ascii: "}") {
            index += 1
            return nil
        }
        guard bytes[index] == UInt8(ascii: "\"") else {
            index = end
            return nil
        }
        let range = readStringRange()
        skipSpace()
        guard !isAtEnd, bytes[index] == UInt8(ascii: ":") else {
            index = end
            return nil
        }
        index += 1
        return range
    }

    public func matches(_ range: Range, _ name: StaticString) -> Bool {
        guard range.count == name.utf8CodeUnitCount else { return false }
        let expected = name.utf8Start
        for offset in 0..<range.count where bytes[range.start + offset] != expected[offset] {
            return false
        }
        return true
    }

    public mutating func skipValue() {
        skipSpace()
        guard !isAtEnd else { return }
        switch bytes[index] {
        case UInt8(ascii: "{"), UInt8(ascii: "["):
            skipNested()
        case UInt8(ascii: "\""):
            _ = readStringRange()
        default:
            while !isAtEnd, !isValueEnd(bytes[index]) { index += 1 }
        }
    }

    public mutating func integer() -> Int? {
        skipSpace()
        var negative = false
        if !isAtEnd, bytes[index] == UInt8(ascii: "-") {
            negative = true
            index += 1
        }
        var digits = 0
        var value = 0
        while !isAtEnd, bytes[index] >= UInt8(ascii: "0"), bytes[index] <= UInt8(ascii: "9") {
            value = value * 10 + Int(bytes[index] - UInt8(ascii: "0"))
            digits += 1
            index += 1
        }
        while !isAtEnd, !isValueEnd(bytes[index]) { index += 1 }
        guard digits > 0 else { return nil }
        return negative ? -value : value
    }

    public mutating func text() -> String? {
        skipSpace()
        guard !isAtEnd, bytes[index] == UInt8(ascii: "\"") else {
            skipValue()
            return nil
        }
        let range = readStringRange()
        guard range.count <= Self.textLimit else { return nil }
        var scalars = [UInt8]()
        scalars.reserveCapacity(range.count)
        var offset = range.start
        let limit = range.start + range.count
        while offset < limit {
            let byte = bytes[offset]
            if byte == UInt8(ascii: "\\"), offset + 1 < limit {
                offset += 1
                scalars.append(unescaped(bytes[offset]))
            } else {
                scalars.append(byte)
            }
            offset += 1
        }
        return String(decoding: scalars, as: UTF8.self)
    }

    private func unescaped(_ byte: UInt8) -> UInt8 {
        switch byte {
        case UInt8(ascii: "n"): UInt8(ascii: "\n")
        case UInt8(ascii: "t"): UInt8(ascii: "\t")
        case UInt8(ascii: "r"): UInt8(ascii: "\r")
        default: byte
        }
    }

    private func isValueEnd(_ byte: UInt8) -> Bool {
        byte == UInt8(ascii: ",") || byte == UInt8(ascii: "}") || byte == UInt8(ascii: "]")
            || byte == UInt8(ascii: " ") || byte == UInt8(ascii: "\n") || byte == UInt8(ascii: "\t")
            || byte == UInt8(ascii: "\r")
    }

    private mutating func skipSpace() {
        while !isAtEnd {
            switch bytes[index] {
            case UInt8(ascii: " "), UInt8(ascii: "\n"), UInt8(ascii: "\t"), UInt8(ascii: "\r"):
                index += 1
            default:
                return
            }
        }
    }

    private mutating func readStringRange() -> Range {
        index += 1
        let start = index
        while !isAtEnd {
            let byte = bytes[index]
            if byte == UInt8(ascii: "\\") {
                index += 2
                continue
            }
            if byte == UInt8(ascii: "\"") {
                let range = Range(start: start, count: index - start)
                index += 1
                return range
            }
            index += 1
        }
        return Range(start: start, count: max(0, end - start))
    }

    private mutating func skipNested() {
        var depth = 0
        while !isAtEnd {
            let byte = bytes[index]
            switch byte {
            case UInt8(ascii: "{"), UInt8(ascii: "["):
                depth += 1
                index += 1
            case UInt8(ascii: "}"), UInt8(ascii: "]"):
                depth -= 1
                index += 1
                if depth == 0 { return }
            case UInt8(ascii: "\""):
                _ = readStringRange()
            default:
                index += 1
            }
        }
    }
}
