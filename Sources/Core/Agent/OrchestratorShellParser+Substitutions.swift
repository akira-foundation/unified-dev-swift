import Foundation

extension OrchestratorShellParser {
    private static let deepestNesting = 16
    private static let parameterName = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_".unicodeScalars)
    private static let simpleDelimiter = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.".unicodeScalars)
    private static let keepsItsBackslashInBackticks: Set<Unicode.Scalar> = ["$", "`", "\\"]

    mutating func enterSubstitution(opening: Unicode.Scalar) {
        guard nesting < Self.deepestNesting else {
            parsed.isUnreadable = true
            return
        }
        if !heredocs.isEmpty { parsed.isUnreadable = true }
        if opening == "`" { enterBackticks() }
        if opening == "$", next == "(" { enterParentheses() }
    }

    mutating func noteUnreadableDollar() {
        switch next {
        case "{":
            noteParameterExpansion()
        case "'", "\\", "[":
            parsed.isUnreadable = true
        case "(":
            if index + 1 < scalars.count, scalars[index + 1] == "(" { parsed.isUnreadable = true }
        default:
            break
        }
    }

    mutating func noteParameterExpansion() {
        var cursor = index + 1
        while cursor < scalars.count, Self.parameterName.contains(scalars[cursor]) { cursor += 1 }
        let isPlainName = cursor > index + 1 && cursor < scalars.count && scalars[cursor] == "}"
        if !isPlainName { parsed.isUnreadable = true }
    }

    mutating func enterParentheses() {
        var inner = OrchestratorShellParser(scalars: scalars, entersSubstitutions: true)
        inner.index = index + 1
        inner.endsAtParenthesis = true
        inner.nesting = nesting + 1
        inner.run()
        if !inner.foundParenthesis { parsed.isUnreadable = true }
        absorb(inner.parsed)
        index = inner.index
    }

    mutating func enterBackticks() {
        var text = String.UnicodeScalarView()
        while let scalar = next {
            index += 1
            if scalar == "`" {
                absorb(OrchestratorShellParser.parseIntoSubstitutions(String(text), nesting: nesting + 1))
                return
            }
            guard scalar == "\\", let following = next else {
                text.append(scalar)
                continue
            }
            index += 1
            if following == "\"" { parsed.isUnreadable = true }
            if !Self.keepsItsBackslashInBackticks.contains(following) { text.append(scalar) }
            text.append(following)
        }
        parsed.isUnreadable = true
    }

    mutating func absorb(_ inner: Parsed) {
        let offset = parsed.clauses.count
        parsed.clausesWithExpansions.formUnion(inner.clausesWithExpansions.map { $0 + offset })
        parsed.clauses += inner.clauses
        parsed.writesFile = parsed.writesFile || inner.writesFile
        parsed.isUnreadable = parsed.isUnreadable || inner.isUnreadable
    }

    mutating func heredocOrHereString() {
        parsed.isPlain = false
        if next == "<" {
            index += 1
            append("<")
            endWord()
            return
        }
        endWord()
        let dropsTabs = next == "-"
        if dropsTabs { index += 1 }
        while next == " " || next == "\t" { index += 1 }
        var delimiter = String.UnicodeScalarView()
        var isLiteral = false
        while let scalar = next, ![" ", "\t", "\n", ";", "|", "&", ")", "<", ">"].contains(scalar) {
            index += 1
            switch scalar {
            case "'", "\"":
                isLiteral = true
                readDelimiterQuote(closing: scalar, into: &delimiter)
            case "\\":
                isLiteral = true
                if let following = next {
                    index += 1
                    delimiter.append(following)
                }
            default:
                delimiter.append(scalar)
            }
        }
        guard !delimiter.isEmpty, delimiter.allSatisfy(Self.simpleDelimiter.contains) else {
            parsed.isUnreadable = true
            return
        }
        heredocs.append(Heredoc(delimiter: String(delimiter), isLiteral: isLiteral, dropsTabs: dropsTabs))
    }

    private mutating func readDelimiterQuote(closing: Unicode.Scalar, into delimiter: inout String.UnicodeScalarView) {
        while let scalar = next {
            index += 1
            if scalar == closing { return }
            delimiter.append(scalar)
        }
        parsed.isUnreadable = true
    }

    mutating func skipHeredocBodies() {
        for heredoc in heredocs {
            var isClosed = false
            while next != nil, !isClosed {
                var line = String.UnicodeScalarView()
                while let scalar = next, scalar != "\n" {
                    index += 1
                    line.append(scalar)
                }
                if next == "\n" { index += 1 }
                let text = heredoc.dropsTabs ? String(String(line).drop { $0 == "\t" }) : String(line)
                isClosed = text == heredoc.delimiter
                if !isClosed, !heredoc.isLiteral, text.contains("$") || text.contains("`") || text.hasSuffix("\\") {
                    parsed.isUnreadable = true
                }
            }
            if !isClosed { parsed.isUnreadable = true }
        }
        heredocs = []
    }

    mutating func closeHeredocs() {
        if !heredocs.isEmpty {
            parsed.isUnreadable = true
            heredocs = []
        }
    }
}
