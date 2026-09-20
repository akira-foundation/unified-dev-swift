import Foundation

enum BridgeMarkerLookalike {
    static func resembles(_ line: some StringProtocol) -> Bool {
        guard let shape = shape(of: line) else { return false }
        return words.contains { spells(shape, $0) }
    }

    private static let words: [[Character]] = [
        BridgeUntrustedText.opening,
        BridgeUntrustedText.closing,
        BridgeUntrustedText.workspaceMessageOpening,
        BridgeUntrustedText.workspaceMessageClosing,
    ].compactMap { shape(of: $0) }

    private static func spells(_ shape: [Character], _ word: [Character]) -> Bool {
        guard shape.count == word.count else { return false }
        return zip(shape, word).allSatisfy { $0 == $1 || !$0.isASCII }
    }

    private static func shape(of line: some StringProtocol) -> [Character]? {
        let scalars = Array(normalised(line).unicodeScalars.filter(carries))

        var start = 0
        while start < scalars.count, isRule(scalars[start]) { start += 1 }
        guard start > 0 else { return nil }

        var end = scalars.count
        while end > start, isRule(scalars[end - 1]) { end -= 1 }
        guard end > start else { return nil }

        let middle = scalars[start ..< end]
        guard middle.allSatisfy({ !isRule($0) }) else { return nil }
        return Array(String(String.UnicodeScalarView(middle)).uppercased())
    }

    private static func normalised(_ line: some StringProtocol) -> String {
        let text = String(line)
        guard !text.unicodeScalars.allSatisfy(\.isASCII) else { return text }
        return text.precomposedStringWithCompatibilityMapping
    }

    private static func carries(_ scalar: Unicode.Scalar) -> Bool {
        if isRule(scalar) { return true }
        guard !scalar.properties.isDefaultIgnorableCodePoint else { return false }
        return Character(scalar).isLetter
    }

    private static let rules: Set<Unicode.Scalar> = [
        "-", "_", "=", "~", "*",
        "\u{2010}", "\u{2011}", "\u{2012}", "\u{2013}", "\u{2014}", "\u{2015}",
        "\u{2212}", "\u{30FC}", "\u{FE58}", "\u{FE63}", "\u{FF0D}",
    ]

    private static func isRule(_ scalar: Unicode.Scalar) -> Bool {
        rules.contains(scalar) || scalar.properties.generalCategory == .dashPunctuation
    }
}
