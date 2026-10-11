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
    public private(set) var closedObject = false

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
        closedObject = false
        skipSpace()
        while !isAtEnd, bytes[index] == UInt8(ascii: ",") {
            index += 1
            skipSpace()
        }
        guard !isAtEnd else { return nil }
        if bytes[index] == UInt8(ascii: "}") {
            index += 1
            closedObject = true
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
        var overflowed = false
        while !isAtEnd, isDigit(bytes[index]) {
            let (scaled, scaleOverflow) = value.multipliedReportingOverflow(by: 10)
            let (added, addOverflow) = scaled.addingReportingOverflow(Int(bytes[index] - UInt8(ascii: "0")))
            if scaleOverflow || addOverflow { overflowed = true } else { value = added }
            digits += 1
            index += 1
        }
        var notWhole = false
        while !isAtEnd, !isValueEnd(bytes[index]) {
            switch bytes[index] {
            case UInt8(ascii: "."), UInt8(ascii: "e"), UInt8(ascii: "E"):
                notWhole = true
            default:
                break
            }
            index += 1
        }
        guard digits > 0, !overflowed, !notWhole else { return nil }
        return negative ? -value : value
    }

    private func isDigit(_ byte: UInt8) -> Bool {
        byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")
    }

    public mutating func text() -> String? {
        skipSpace()
        guard !isAtEnd, bytes[index] == UInt8(ascii: "\"") else {
            skipValue()
            return nil
        }
        let range = readStringRange()
        guard range.count <= Self.textLimit else { return nil }
        var text = ""
        text.reserveCapacity(range.count)
        var scalars = [UInt8]()
        var offset = range.start
        let limit = range.start + range.count

        func flush() {
            guard !scalars.isEmpty else { return }
            text += String(decoding: scalars, as: UTF8.self)
            scalars.removeAll(keepingCapacity: true)
        }

        while offset < limit {
            let byte = bytes[offset]
            guard byte == UInt8(ascii: "\\"), offset + 1 < limit else {
                scalars.append(byte)
                offset += 1
                continue
            }
            offset += 1
            if bytes[offset] == UInt8(ascii: "u") {
                flush()
                guard let (scalar, read) = escapedScalar(at: offset + 1, limit: limit) else { return nil }
                text.unicodeScalars.append(scalar)
                offset += 1 + read
                continue
            }
            scalars.append(unescaped(bytes[offset]))
            offset += 1
        }
        flush()
        return text
    }

    private func escapedScalar(at start: Int, limit: Int) -> (Unicode.Scalar, Int)? {
        guard let first = hex(at: start, limit: limit) else { return nil }
        guard (0xD800...0xDBFF).contains(first) else {
            guard !(0xDC00...0xDFFF).contains(first), let scalar = Unicode.Scalar(first) else { return nil }
            return (scalar, 4)
        }
        guard start + 6 + 4 <= limit,
              bytes[start + 4] == UInt8(ascii: "\\"), bytes[start + 5] == UInt8(ascii: "u"),
              let low = hex(at: start + 6, limit: limit), (0xDC00...0xDFFF).contains(low),
              let scalar = Unicode.Scalar(0x10000 + (first - 0xD800) * 0x400 + (low - 0xDC00))
        else { return nil }
        return (scalar, 10)
    }

    private func hex(at start: Int, limit: Int) -> UInt32? {
        guard start + 4 <= limit else { return nil }
        var value: UInt32 = 0
        for offset in start..<(start + 4) {
            guard let digit = hexDigit(bytes[offset]) else { return nil }
            value = value << 4 | digit
        }
        return value
    }

    private func hexDigit(_ byte: UInt8) -> UInt32? {
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): UInt32(byte - UInt8(ascii: "0"))
        case UInt8(ascii: "a")...UInt8(ascii: "f"): UInt32(byte - UInt8(ascii: "a")) + 10
        case UInt8(ascii: "A")...UInt8(ascii: "F"): UInt32(byte - UInt8(ascii: "A")) + 10
        default: nil
        }
    }

    private func unescaped(_ byte: UInt8) -> UInt8 {
        switch byte {
        case UInt8(ascii: "n"): UInt8(ascii: "\n")
        case UInt8(ascii: "t"): UInt8(ascii: "\t")
        case UInt8(ascii: "r"): UInt8(ascii: "\r")
        case UInt8(ascii: "b"): 0x08
        case UInt8(ascii: "f"): 0x0C
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
