import Foundation

public struct DiffDocument: Sendable {
    public var file: FileDiff
    public var language: Language
    public var carries: [Int: LexState]
    public var emphasis: [Int: [Range<String.Index>]]
    public var maxColumns: Int

    private static let emphasisLimit = 4_000

    private static let columnLimit = 800

    public static func sourceOffset(in lines: [DiffLine?], offset: Int, source: String) -> Int? {
        guard offset >= 0 else { return nil }
        var start = 0
        let full = source as NSString
        for entry in lines {
            let length = entry?.text.utf16.count ?? 0
            if offset >= start, offset < start + length {
                guard let entry, let number = entry.newNumber, entry.kind == .addition || entry.kind == .context else { return nil }
                let lineStart = CodeLocation.offset(in: source, line: number)
                guard lineStart < full.length else { return nil }
                let range = full.lineRange(for: NSRange(location: lineStart, length: 0))
                let text = full.substring(with: range).trimmingCharacters(in: .newlines)
                guard text.utf8.elementsEqual(entry.text.utf8) else { return nil }
                return lineStart + offset - start
            }
            start += length + 1
        }
        return nil
    }

    public static func contains(_ location: CodeLocation, in file: FileDiff) -> Bool {
        file.hunks.flatMap(\.lines).contains { ($0.kind == .addition || $0.kind == .context) && $0.newNumber == location.line }
    }

    public static func parse(patch: String, path: String) -> FileDiff? {
        let files = DiffParser.parse(patch)
        return files.first { $0.displayPath == path } ?? files.first
    }

    public static func prepare(file: FileDiff, path: String, language override: Language? = nil) -> DiffDocument {
        let language = override ?? Language.detect(path: path)
        let needsCarry = language != .plainText
        var carries: [Int: LexState] = [:]
        var emphasis: [Int: [Range<String.Index>]] = [:]
        var oldState = LexState()
        var newState = LexState()
        var maxColumns = 0
        var pairsComputed = 0

        for hunk in file.hunks {
            var deletions: [DiffLine] = []
            var additions: [DiffLine] = []

            func flushPairs() {
                let count = min(deletions.count, additions.count)
                for offset in 0..<count {
                    guard pairsComputed < emphasisLimit else { break }
                    pairsComputed += 1
                    let before = deletions[offset]
                    let after = additions[offset]
                    let (left, right) = DiffParser.intraLineDiff(before.text, after.text)
                    if !left.isEmpty { emphasis[before.index] = left }
                    if !right.isEmpty { emphasis[after.index] = right }
                }
                deletions.removeAll(keepingCapacity: true)
                additions.removeAll(keepingCapacity: true)
            }

            for line in hunk.lines {
                maxColumns = max(maxColumns, CodeColumns.count(of: line.text))

                switch line.kind {
                case .context:
                    flushPairs()
                    guard needsCarry else { continue }
                    carries[line.index] = newState
                    var oldCopy = oldState
                    _ = SyntaxHighlighter.tokenize(line: line.text, language: language, carry: &oldCopy)
                    oldState = oldCopy
                    _ = SyntaxHighlighter.tokenize(line: line.text, language: language, carry: &newState)
                case .deletion:
                    deletions.append(line)
                    guard needsCarry else { continue }
                    carries[line.index] = oldState
                    _ = SyntaxHighlighter.tokenize(line: line.text, language: language, carry: &oldState)
                case .addition:
                    additions.append(line)
                    guard needsCarry else { continue }
                    carries[line.index] = newState
                    _ = SyntaxHighlighter.tokenize(line: line.text, language: language, carry: &newState)
                case .noNewline:
                    break
                }
            }
            flushPairs()
        }

        return DiffDocument(
            file: file,
            language: language,
            carries: carries,
            emphasis: emphasis,
            maxColumns: min(maxColumns, columnLimit)
        )
    }

    public func linesToPrime(limit: Int) -> [(text: String, carry: LexState)] {
        guard limit > 0 else { return [] }
        var result: [(text: String, carry: LexState)] = []
        result.reserveCapacity(limit)
        for hunk in file.hunks {
            for line in hunk.lines where line.kind != .noNewline {
                result.append((line.text, carries[line.index] ?? LexState()))
                if result.count == limit { return result }
            }
        }
        return result
    }
}
