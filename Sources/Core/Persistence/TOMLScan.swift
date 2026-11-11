import Foundation

enum TOMLScan {
    struct Outline {
        var headers: [(index: Int, path: [String], isArray: Bool)] = []
        var assignments: [(index: Int, end: Int)] = []
    }

    static func outline(_ lines: [String]) -> Outline {
        var outline = Outline()
        var index = 0
        while index < lines.count {
            if let path = SettingsDocument.tableHeader(in: lines[index]) {
                let isArray = lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("[[")
                outline.headers.append((index, path, isArray))
                index += 1
                continue
            }
            guard SettingsDocument.keyAssignment(in: lines[index]) != nil else {
                index += 1
                continue
            }
            let end = end(of: lines, from: index)
            outline.assignments.append((index, end))
            index = end
        }
        return outline
    }

    static func withoutTrailingComment(_ text: String) -> String {
        let scanned = scan(text)
        guard let hash = scanned.comment else { return text }
        return text[..<hash].trimmingCharacters(in: .whitespaces)
    }
    static func value(of line: String) -> String? {
        guard let equals = line.firstIndex(of: "=") else { return nil }
        return line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
    }

    static func end(of lines: [String], from index: Int) -> Int {
        guard let value = value(of: lines[index]) else { return index + 1 }

        for delimiter in ["'''", "\"\"\""] where value.hasPrefix(delimiter) {
            if value.dropFirst(delimiter.count).contains(delimiter) { return index + 1 }
            var cursor = index + 1
            while cursor < lines.count {
                if lines[cursor].contains(delimiter) { return cursor + 1 }
                cursor += 1
            }
            return lines.count
        }

        guard value.hasPrefix("[") || value.hasPrefix("{") else { return index + 1 }
        var depth = scan(value).depth
        var cursor = index
        while depth > 0 {
            cursor += 1
            guard cursor < lines.count else { return lines.count }
            depth += scan(lines[cursor]).depth
        }
        return cursor + 1
    }

    static func inlineTable(_ value: String) -> (entries: [String], comment: String?)? {
        guard value.hasPrefix("{") else { return nil }
        let outer = scan(value)
        guard outer.depth == 0, let close = outer.close else { return nil }
        let after = value[value.index(after: close)...].trimmingCharacters(in: .whitespaces)
        guard after.isEmpty || after.hasPrefix("#") else { return nil }
        let inner = String(value[value.index(after: value.startIndex)..<close])
        let entries = scan(inner, splittingAt: ",").parts
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return (entries, after.isEmpty ? nil : after)
    }

    private static func scan(
        _ text: String, splittingAt separator: Character? = nil
    ) -> (parts: [String], depth: Int, close: String.Index?, comment: String.Index?) {
        var parts: [String] = []
        var current = ""
        var depth = 0
        var quote: Character?
        var escaped = false
        var close: String.Index?
        for index in text.indices {
            let character = text[index]
            if let active = quote {
                current.append(character)
                switch (escaped, character) {
                case (true, _): escaped = false
                case (false, "\\") where active == "\"": escaped = true
                case (false, active): quote = nil
                default: break
                }
                continue
            }
            switch character {
            case "\"", "'": quote = character
            case "#": return (parts + [current], depth, close, index)
            case "{", "[": depth += 1
            case "}", "]":
                depth -= 1
                if depth == 0, close == nil, character == "}" { close = index }
            default: break
            }
            guard character == separator, depth == 0 else {
                current.append(character)
                continue
            }
            parts.append(current)
            current = ""
        }
        return (parts + [current], depth, close, nil)
    }
}
