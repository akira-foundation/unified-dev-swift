import Foundation

public enum BrowserDownloadFile {
    public static let nameLimit = 200

    public static func name(from suggested: String) -> String {
        var name = String(suggested.unicodeScalars.filter { scalar in
            !CharacterSet.controlCharacters.contains(scalar) && scalar != ":"
        })

        name = name.split(separator: "/").last.map(String.init) ?? ""
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        while name.hasPrefix(".") { name.removeFirst() }
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else { return "download" }
        return shortened(name)
    }

    private static func shortened(_ name: String) -> String {
        guard name.count > nameLimit else { return name }
        let parts = parted(name)
        guard !parts.ext.isEmpty, parts.ext.count <= 20 else {
            return String(name.prefix(nameLimit))
        }
        return String(parts.stem.prefix(nameLimit - parts.ext.count - 1)) + "." + parts.ext
    }

    static func parted(_ name: String) -> (stem: String, ext: String) {
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return (name, "") }
        let ext = String(name[name.index(after: dot)...])
        guard !ext.isEmpty else { return (name, "") }
        return (String(name[..<dot]), ext)
    }

    public static func filename(for suggested: String, isTaken: (String) -> Bool) -> String {
        let name = name(from: suggested)
        guard isTaken(name) else { return name }

        for number in 2...1_000 {
            let candidate = numbered(name, number)
            if !isTaken(candidate) { return candidate }
        }
        return numbered(name, Int(Date().timeIntervalSince1970))
    }

    static func numbered(_ name: String, _ number: Int) -> String {
        let parts = parted(name)
        guard !parts.ext.isEmpty else { return "\(name)-\(number)" }
        return "\(parts.stem)-\(number).\(parts.ext)"
    }

    public static func size(_ bytes: Int64) -> String {
        guard bytes >= 1_000 else { return "\(max(bytes, 0)) bytes" }

        var value = Double(bytes)
        var units = ["kB", "MB", "GB", "TB"].makeIterator()
        var unit = "kB"
        while value >= 1_000, let next = units.next() {
            value /= 1_000
            unit = next
        }
        return String(format: "%.1f %@", value, unit)
    }

    public static func progress(received: Int64, expected: Int64) -> String {
        guard expected > 0 else { return size(received) }
        return "\(size(received)) of \(size(expected))"
    }
}
