import Foundation

enum BridgeMarkerLookalike {
    static func resembles(_ line: some StringProtocol) -> Bool {
        guard let shape = shape(of: line) else { return false }
        return words.contains(shape)
    }

    private static let words: Set<String> = Set(
        [
            BridgeUntrustedText.opening,
            BridgeUntrustedText.closing,
            BridgeUntrustedText.workspaceMessageOpening,
            BridgeUntrustedText.workspaceMessageClosing,
        ].compactMap { shape(of: $0) }
    )

    private static func shape(of line: some StringProtocol) -> String? {
        let scalars = Array(String(line).precomposedStringWithCompatibilityMapping.unicodeScalars.filter(carries))

        var start = 0
        while start < scalars.count, isDash(scalars[start]) { start += 1 }
        guard start > 0 else { return nil }

        var end = scalars.count
        while end > start, isDash(scalars[end - 1]) { end -= 1 }
        guard end < scalars.count, end > start else { return nil }

        let middle = String(String.UnicodeScalarView(scalars[start ..< end])).uppercased()
        guard middle.allSatisfy(\.isLetter) else { return nil }
        return String(middle.map { latin[$0] ?? $0 })
    }

    private static func carries(_ scalar: Unicode.Scalar) -> Bool {
        if isDash(scalar) { return true }
        if scalar.properties.isWhitespace { return false }
        return !ignored.contains(scalar.properties.generalCategory)
    }

    private static let ignored: Set<Unicode.GeneralCategory> = [
        .format, .control, .nonspacingMark, .otherLetter,
    ]

    private static let dashes: Set<Unicode.Scalar> = [
        "-", "\u{2010}", "\u{2011}", "\u{2012}", "\u{2013}", "\u{2014}", "\u{2015}",
        "\u{2212}", "\u{FE58}", "\u{FE63}", "\u{FF0D}",
    ]

    private static func isDash(_ scalar: Unicode.Scalar) -> Bool {
        dashes.contains(scalar) || scalar.properties.generalCategory == .dashPunctuation
    }

    private static let latin: [Character: Character] = [
        "\u{0410}": "A", "\u{0415}": "E", "\u{0405}": "S", "\u{0406}": "I", "\u{0408}": "J",
        "\u{041C}": "M", "\u{041E}": "O", "\u{0420}": "P", "\u{0421}": "C", "\u{0422}": "T",
        "\u{0425}": "X",
        "\u{0391}": "A", "\u{0392}": "B", "\u{0395}": "E", "\u{0396}": "Z", "\u{0397}": "H",
        "\u{0399}": "I", "\u{039A}": "K", "\u{039C}": "M", "\u{039D}": "N", "\u{039F}": "O",
        "\u{03A1}": "P", "\u{03A4}": "T", "\u{03A5}": "Y", "\u{03A7}": "X",
    ]
}
