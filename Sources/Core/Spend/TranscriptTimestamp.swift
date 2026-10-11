import Foundation

public enum TranscriptTimestamp {
    public static func date(from text: String) -> Date? {
        let bytes = [UInt8](text.utf8)
        guard bytes.count >= 19 else { return nil }
        return bytes.withUnsafeBufferPointer { date(from: $0) }
    }

    public static func date(from bytes: UnsafeBufferPointer<UInt8>) -> Date? {
        guard bytes.count >= 19,
              let year = number(bytes, 0, 4),
              let month = number(bytes, 5, 2),
              let day = number(bytes, 8, 2),
              let hour = number(bytes, 11, 2),
              let minute = number(bytes, 14, 2),
              let second = number(bytes, 17, 2),
              (1...12).contains(month), (1...31).contains(day)
        else { return nil }

        var seconds = Double(daysFromCivil(year: year, month: month, day: day)) * 86_400
        seconds += Double(hour * 3600 + minute * 60 + second)
        seconds += fraction(bytes)
        seconds -= offset(bytes)
        return Date(timeIntervalSince1970: seconds)
    }

    static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let shifted = month <= 2 ? year - 1 : year
        let era = (shifted >= 0 ? shifted : shifted - 399) / 400
        let yearOfEra = shifted - era * 400
        let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    private static func fraction(_ bytes: UnsafeBufferPointer<UInt8>) -> Double {
        guard bytes.count > 20, bytes[19] == UInt8(ascii: ".") else { return 0 }
        var value = 0.0
        var scale = 0.1
        var index = 20
        while index < bytes.count, isDigit(bytes[index]) {
            value += Double(bytes[index] - UInt8(ascii: "0")) * scale
            scale /= 10
            index += 1
        }
        return value
    }

    private static func offset(_ bytes: UnsafeBufferPointer<UInt8>) -> Double {
        var index = 19
        while index < bytes.count {
            let byte = bytes[index]
            if byte == UInt8(ascii: "Z") || byte == UInt8(ascii: "z") { return 0 }
            if byte == UInt8(ascii: "+") || byte == UInt8(ascii: "-") {
                guard let hours = number(bytes, index + 1, 2) else { return 0 }
                let separated = index + 3 < bytes.count && bytes[index + 3] == UInt8(ascii: ":")
                let minutes = number(bytes, index + (separated ? 4 : 3), 2) ?? 0
                let magnitude = Double(hours * 3600 + minutes * 60)
                return byte == UInt8(ascii: "+") ? magnitude : -magnitude
            }
            index += 1
        }
        return 0
    }

    private static func number(_ bytes: UnsafeBufferPointer<UInt8>, _ start: Int, _ count: Int) -> Int? {
        guard start + count <= bytes.count else { return nil }
        var value = 0
        for offset in start..<(start + count) {
            guard isDigit(bytes[offset]) else { return nil }
            value = value * 10 + Int(bytes[offset] - UInt8(ascii: "0"))
        }
        return value
    }

    private static func isDigit(_ byte: UInt8) -> Bool {
        byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")
    }
}
