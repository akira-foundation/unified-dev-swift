import Foundation

struct OrchestratorShellParser {
    struct Parsed: Equatable {
        var clauses: [[String]] = []
        var isPlain = true
    }

    static func parse(_ command: String) -> Parsed {
        var parser = OrchestratorShellParser(scalars: Array(command.unicodeScalars))
        parser.run()
        return parser.parsed
    }

    private static let harmlessTargets: Set<String> = ["/dev/null", "/dev/stdout", "/dev/stderr"]
    private static let plainPunctuation = Set("_-./,:=+@%~".unicodeScalars)
    private static let expandsAfter: Set<Unicode.Scalar> = ["=", ":"]

    private let scalars: [Unicode.Scalar]
    private var index = 0
    private var parsed = Parsed()
    private var clause: [String] = []
    private var word = String.UnicodeScalarView()
    private var hasWord = false
    private var wordIsQuoted = false
    private var awaitingTarget = false

    private init(scalars: [Unicode.Scalar]) {
        self.scalars = scalars
    }

    private var next: Unicode.Scalar? { index < scalars.count ? scalars[index] : nil }

    private mutating func run() {
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
            case ";", "\n":
                endClause()
            case "(", ")", "{", "}", "`":
                parsed.isPlain = false
                endClause()
            case " ", "\t":
                endWord()
            default:
                unquoted(scalar)
            }
        }
        endClause()
    }

    private mutating func unquoted(_ scalar: Unicode.Scalar) {
        let isPlainScalar = scalar.isASCII
            && (CharacterSet.alphanumerics.contains(scalar) || Self.plainPunctuation.contains(scalar))
        if !isPlainScalar || expands(scalar) { parsed.isPlain = false }
        append(scalar)
    }

    private func expands(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar {
        case "=": !hasWord
        case "~": !hasWord || word.last.map(Self.expandsAfter.contains) == true
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
            default:
                word.append(scalar)
            }
        }
        parsed.isPlain = false
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
        if awaitingTarget { parsed.isPlain = false }
        if next == ">" { index += 1 }
        guard next == "&" else {
            awaitingTarget = true
            return
        }
        index += 1
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

    private mutating func append(_ scalar: Unicode.Scalar) {
        word.append(scalar)
        hasWord = true
    }

    private mutating func endWord() {
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
        if !Self.harmlessTargets.contains(finished) { parsed.isPlain = false }
        awaitingTarget = false
    }

    private mutating func endClause() {
        endWord()
        if awaitingTarget {
            parsed.isPlain = false
            awaitingTarget = false
        }
        if !clause.isEmpty { parsed.clauses.append(clause) }
        clause = []
    }
}
