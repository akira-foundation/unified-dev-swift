import Core

enum CarryPass {
    static func states(for lines: [String], language: Language) -> [LexState] {
        var state = LexState()
        var result: [LexState] = []
        result.reserveCapacity(lines.count)

        for line in lines {
            result.append(state)
            _ = SyntaxHighlighter.tokenize(line: line, language: language, carry: &state)
        }
        return result
    }
}
