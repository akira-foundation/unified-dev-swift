import SwiftUI
import AppKit
import Core

struct CodeText: View {
    private let line: String
    private let language: Language
    private let carry: LexState
    private var emphasis: [Range<String.Index>] = []
    private var emphasisColor: Color = .clear

    init(line: String, language: Language, carry: LexState) {
        self.line = line
        self.language = language
        self.carry = carry
    }

    func emphasizing(_ ranges: [Range<String.Index>], color: Color) -> CodeText {
        guard !ranges.isEmpty else { return self }
        var copy = self
        copy.emphasis = ranges
        copy.emphasisColor = color
        return copy
    }

    var body: some View {
        Text(
            Self.attributed(
                line: line,
                language: language,
                carry: carry,
                emphasis: emphasis,
                emphasisColor: emphasisColor
            )
        )
        .font(Typo.code)
        .textSelection(.enabled)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

    static func attributed(
        line: String,
        language: Language,
        carry: LexState,
        emphasis: [Range<String.Index>] = [],
        emphasisColor: Color = .clear
    ) -> AttributedString {
        var value = SyntaxCache.attributed(line: line, language: language, carry: carry)
        guard !emphasis.isEmpty else { return value }

        for range in emphasis {
            guard let mapped = attributedRange(for: range, of: line, in: value) else { continue }
            value[mapped].backgroundColor = emphasisColor
        }
        return value
    }

    nonisolated static func color(for kind: TokenKind) -> Color {
        switch kind {
        case .plain: Palette.textPrimary
        case .keyword: Palette.synKeyword
        case .type: Palette.synType
        case .string: Palette.synString
        case .number: Palette.synNumber
        case .comment: Palette.synComment
        case .function: Palette.synFunction
        case .variable: Palette.synVariable
        case .attribute: Palette.synAttribute
        case .operator: Palette.synOperator
        case .punctuation: Palette.synOperator
        case .regex: Palette.synString
        case .constant: Palette.synConstant
        }
    }

    nonisolated static func attributedRange(
        forUTF16 range: Range<Int>,
        of source: String,
        in target: AttributedString
    ) -> Range<AttributedString.Index>? {
        let limit = source.utf16.count
        guard range.lowerBound >= 0, range.upperBound <= limit, range.lowerBound < range.upperBound else {
            return nil
        }
        let lower = String.Index(utf16Offset: range.lowerBound, in: source)
        let upper = String.Index(utf16Offset: range.upperBound, in: source)
        return attributedRange(for: lower..<upper, of: source, in: target)
    }

    nonisolated static func attributedRange(
        for range: Range<String.Index>,
        of source: String,
        in target: AttributedString
    ) -> Range<AttributedString.Index>? {
        guard range.lowerBound >= source.startIndex, range.upperBound <= source.endIndex,
              range.lowerBound < range.upperBound,
              let lower = AttributedString.Index(range.lowerBound, within: target),
              let upper = AttributedString.Index(range.upperBound, within: target),
              lower < upper
        else { return nil }
        return lower..<upper
    }
}
