import Foundation

struct OrchestratorShellParser {
    struct Heredoc {
        var delimiter: String
        var isLiteral: Bool
        var dropsTabs: Bool
    }

    struct Parsed: Equatable {
        var clauses: [[String]] = []
        var isPlain = true
        var writesFile = false
        var isUnreadable = false
        var clausesWithExpansions: Set<Int> = []
    }

    static func parse(_ command: String) -> Parsed {
        var parser = OrchestratorShellParser(scalars: Array(command.unicodeScalars))
        parser.run()
        return parser.parsed
    }

    static func parseIntoSubstitutions(_ command: String, nesting: Int = 0) -> Parsed {
        var parser = OrchestratorShellParser(scalars: Array(command.unicodeScalars), entersSubstitutions: true)
        parser.nesting = nesting
        parser.run()
        parser.closeHeredocs()
        return parser.parsed
    }

    private static let harmlessTargets: Set<String> = ["/dev/null", "/dev/stdout", "/dev/stderr"]
    private static let plainPunctuation = Set("_-./,:=+@%~".unicodeScalars)
    private static let expandsAfter: Set<Unicode.Scalar> = ["=", ":"]

    let scalars: [Unicode.Scalar]
    var index = 0
    var parsed = Parsed()
    private var clause: [String] = []
    private var word = String.UnicodeScalarView()
    private var hasWord = false
    private var wordIsQuoted = false
    private var awaitingTarget = false
    private var clauseExpands = false
    let entersSubstitutions: Bool
    var endsAtParenthesis = false
    private var parentheses = 0
    var foundParenthesis = false
    var nesting = 0
    var heredocs: [Heredoc] = []

    init(scalars: [Unicode.Scalar], entersSubstitutions: Bool = false) {
        self.scalars = scalars
        self.entersSubstitutions = entersSubstitutions
    }

    var next: Unicode.Scalar? { index < scalars.count ? scalars[index] : nil }

    mutating func run() {
        while let scalar = next {
            index += 1
            switch scalar {
            case "'": singleQuoted()
            case "\"": doubleQuoted()
            case "\\": escaped()
            case ">": redirect()
            case "&": ampersand()
            case "|":
                if next == "|" { index += 1 }
                endClause()
            case "\n":
                if parentheses > 0, !heredocs.isEmpty { parsed.isUnreadable = true }
                endClause()
                skipHeredocBodies()
            case ";":
                endClause()
            case "$" where entersSubstitutions:
                noteExpansion()
                noteUnreadableDollar()
                unquoted(scalar)
                takePlainParameter()
            case "`" where entersSubstitutions:
                parsed.isPlain = false
                noteExpansion()
                append("$")
                enterSubstitution(opening: scalar)
            case "(" where entersSubstitutions && !isAfterDollar && (hasWord || next == "("):
                parsed.isUnreadable = true
                punctuation(scalar)
            case "{" where entersSubstitutions && next == "}":
                index += 1
                parsed.isPlain = false
                append("{")
                append("}")
            case "{" where entersSubstitutions && !isAfterDollar && (hasWord || !isBlankOrEnd(next)):
                parsed.isUnreadable = true
                punctuation(scalar)
            case "<" where entersSubstitutions && next == "<":
                index += 1
                heredocOrHereString()
            case ")" where endsAtParenthesis && parentheses == 0:
                endClause()
                closeHeredocs()
                foundParenthesis = true
                return
            case "{" where entersSubstitutions && isPastTheHead, "}" where entersSubstitutions && isPastTheHead:
                parsed.isUnreadable = true
                punctuation(scalar)
            case "(", ")", "{", "}", "`":
                punctuation(scalar)
            case " ", "\t":
                endWord()
            default:
                unquoted(scalar)
            }
        }
        endClause()
    }

    private var isAfterDollar: Bool { word.last == "$" }

    private var isPastTheHead: Bool { hasWord || clause.contains { !Self.leavesTheHeadOpen($0) } }

    private func isBlankOrEnd(_ scalar: Unicode.Scalar?) -> Bool {
        scalar.map { [" ", "\t", "\n"].contains($0) } ?? true
    }

    mutating func noteExpansion() {
        clauseExpands = true
    }

    private mutating func punctuation(_ scalar: Unicode.Scalar) {
        if scalar == "(" { parentheses += 1 }
        if scalar == ")" { parentheses -= 1 }
        parsed.isPlain = false
        endClause()
    }

    private mutating func unquoted(_ scalar: Unicode.Scalar) {
        let isPlainScalar = scalar.isASCII
            && (CharacterSet.alphanumerics.contains(scalar) || Self.plainPunctuation.contains(scalar))
        if !isPlainScalar || expands(scalar) { parsed.isPlain = false }
        if entersSubstitutions, scalar == "#", word.isEmpty { parsed.isUnreadable = true }
        append(scalar)
    }

    private func expands(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar {
        case "=": word.isEmpty
        case "~": word.isEmpty || word.last.map(Self.expandsAfter.contains) == true
        default: false
        }
    }

    private mutating func singleQuoted() {
        hasWord = true
        wordIsQuoted = true
        while let scalar = next {
            index += 1
            if scalar == "'" { return }
            word.append(scalar)
        }
        parsed.isPlain = false
        parsed.isUnreadable = true
    }

    private mutating func doubleQuoted() {
        hasWord = true
        wordIsQuoted = true
        while let scalar = next {
            index += 1
            switch scalar {
            case "\"":
                return
            case "\\":
                insideDoubleQuotesEscape()
            case "$", "`":
                parsed.isPlain = false
                word.append(scalar)
                if entersSubstitutions {
                    noteExpansion()
                    if scalar == "$" { noteUnreadableDollar() }
                    enterSubstitution(opening: scalar)
                }
            default:
                word.append(scalar)
            }
        }
        parsed.isPlain = false
        parsed.isUnreadable = true
    }

    private mutating func insideDoubleQuotesEscape() {
        guard let following = next else { return }
        index += 1
        switch following {
        case "\n":
            return
        case "\"", "\\", "$", "`":
            word.append(following)
        default:
            word.append("\\")
            word.append(following)
        }
    }

    private mutating func escaped() {
        parsed.isPlain = false
        guard let following = next else { return }
        index += 1
        if following != "\n" { append(following) }
    }

    private mutating func redirect() {
        if hasWord, !wordIsQuoted, word.allSatisfy({ ("0"..."9").contains($0) }) {
            if word.count > 1 { parsed.isPlain = false }
            word = String.UnicodeScalarView()
            hasWord = false
        }
        endWord()
        if awaitingTarget {
            parsed.isPlain = false
            parsed.isUnreadable = true
        }
        let appends = next == ">"
        if appends { index += 1 }
        guard next == "&" else {
            awaitingTarget = true
            return
        }
        index += 1
        if appends { parsed.isPlain = false }
        duplicatedDescriptor()
    }

    private mutating func duplicatedDescriptor() {
        let start = index
        if next == "-" {
            index += 1
        } else {
            while let scalar = next, ("0"..."9").contains(scalar) { index += 1 }
        }
        let endsTheWord = next.map { [" ", "\t", "\n", ";", "|", "&"].contains($0) } ?? true
        if index == start || !endsTheWord {
            parsed.isPlain = false
            awaitingTarget = true
        }
    }

    private mutating func ampersand() {
        if next == "&" {
            index += 1
        } else {
            parsed.isPlain = false
        }
        endClause()
    }

    mutating func append(_ scalar: Unicode.Scalar) {
        word.append(scalar)
        hasWord = true
    }

    mutating func endWord() {
        defer {
            word = String.UnicodeScalarView()
            hasWord = false
            wordIsQuoted = false
        }
        guard hasWord else { return }
        let finished = String(word)
        guard awaitingTarget else {
            clause.append(finished)
            return
        }
        if !Self.harmlessTargets.contains(finished) {
            parsed.isPlain = false
            parsed.writesFile = true
        }
        awaitingTarget = false
    }

    private mutating func endClause() {
        endWord()
        if awaitingTarget {
            parsed.isPlain = false
            parsed.isUnreadable = true
            awaitingTarget = false
        }
        if !clause.isEmpty {
            if clauseExpands { parsed.clausesWithExpansions.insert(parsed.clauses.count) }
            parsed.clauses.append(clause)
        }
        clause = []
        clauseExpands = false
    }
}
