import Foundation

extension SettingsDocument {
    mutating func openTables(along path: [String]) {
        let table = Array(path.dropLast())
        guard !table.isEmpty else { return }
        var lines = text.components(separatedBy: "\n")
        var moved: [String] = []
        var comments: [String] = []
        var opened = false
        var current: [String] = []
        var hasHeader = false
        var index = 0
        while index < lines.count {
            let line = lines[index]
            if let header = Self.tableHeader(in: line) {
                current = header
                hasHeader = hasHeader || header == table
                index += 1
                continue
            }
            guard let (written, _) = Self.keyAssignment(in: line),
                  current.count < table.count,
                  let found = Self.open(line, defining: current + written, under: table)
            else {
                index += 1
                continue
            }
            moved += found.entries
            comments += found.comment.map { [$0] } ?? []
            opened = true
            lines.remove(at: index)
        }
        guard opened, !hasHeader else { return }
        let trailing = text.hasSuffix("\n") && lines.last == ""
        if trailing { lines.removeLast() }
        if let last = lines.last, !last.trimmingCharacters(in: .whitespaces).isEmpty { lines.append("") }
        lines += comments + [Self.header(table)] + moved
        self = SettingsDocument(text: lines.joined(separator: "\n") + (trailing ? "\n" : ""), exists: exists)
    }

    private static func open(
        _ line: String, defining full: [String], under table: [String]
    ) -> (entries: [String], comment: String?)? {
        guard let equals = line.firstIndex(of: "=") else { return nil }
        let value = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
        if full.count > table.count, Array(full.prefix(table.count)) == table {
            guard TOMLScan.isComplete(value) else { return nil }
            let key = full.dropFirst(table.count).map { needsQuoting($0) ? "\"\($0)\"" : $0 }.joined(separator: ".")
            return (["\(key) = \(value)"], nil)
        }
        guard full.count <= table.count, Array(table.prefix(full.count)) == full,
              let inline = TOMLScan.inlineTable(value) else { return nil }
        let rest = table.dropFirst(full.count).map { needsQuoting($0) ? "\"\($0)\"" : $0 }
        let entries = inline.entries.map { entry in
            rest.isEmpty ? entry : rest.joined(separator: ".") + "." + entry
        }
        return (entries, inline.comment)
    }

    private static func header(_ table: [String]) -> String {
        "[" + table.map { needsQuoting($0) ? "\"\($0)\"" : $0 }.joined(separator: ".") + "]"
    }
}

enum TOMLScan {
    static func isComplete(_ value: String) -> Bool {
        for delimiter in ["'''", "\"\"\""] where value.hasPrefix(delimiter) {
            return value.dropFirst(delimiter.count).contains(delimiter)
        }
        return split(value, at: nil).depth == 0
    }

    static func inlineTable(_ value: String) -> (entries: [String], comment: String?)? {
        guard value.hasPrefix("{") else { return nil }
        let scanned = split(value, at: ",")
        guard scanned.depth == 0, let close = scanned.close else { return nil }
        let inner = value[value.index(after: value.startIndex)..<close]
        let after = value[value.index(after: close)...].trimmingCharacters(in: .whitespaces)
        guard after.isEmpty || after.hasPrefix("#") else { return nil }
        let entries = split(String(inner), at: ",").parts
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return (entries, after.isEmpty ? nil : after)
    }

    private static func split(
        _ text: String, at separator: Character?
    ) -> (parts: [String], depth: Int, close: String.Index?) {
        var parts: [String] = []
        var current = ""
        var depth = 0
        var quote: Character?
        var close: String.Index?
        for index in text.indices {
            let character = text[index]
            if let active = quote {
                if character == active { quote = nil }
                current.append(character)
                continue
            }
            switch character {
            case "\"", "'": quote = character
            case "#" where depth == 0: return (parts + [current], depth, close)
            case "{", "[": depth += 1
            case "}", "]":
                depth -= 1
                if depth == 0, close == nil, character == "}" { close = index }
            default: break
            }
            if character == separator, depth == 0 {
                parts.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        return (parts + [current], depth, close)
    }
}
