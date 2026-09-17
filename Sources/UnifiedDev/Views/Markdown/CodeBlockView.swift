import SwiftUI
import AppKit
import Core

public struct CodeBlockView: View {
    private static let lineCap = 2_000

    private let code: String
    private let language: Language
    @State private var showsAllLines = false

    @Environment(\.markdownIsStreaming) private var isStreaming

    public init(code: String, language: Language) {
        self.code = code
        self.language = language
    }

    public var body: some View {
        let prepared = CodeBlockPreparationCache.prepared(
            code: code, language: language, isStreaming: isStreaming
        )
        let visibleCount = showsAllLines ? prepared.lines.count : min(prepared.lines.count, Self.lineCap)

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Metrics.spacing) {
                Text(Self.displayName(for: language))
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textTertiary)
                Spacer(minLength: MarkdownMetrics.blockGap)
                CopyButton(text: code, title: "Copy code", size: MarkdownMetrics.iconButton)
            }
            .padding(.horizontal, MarkdownMetrics.blockGap)
            .padding(.vertical, Metrics.spacing)

            ScrollView(.horizontal) {
                Text(highlighted(prepared, upTo: visibleCount))
                    .font(Typo.code)
                    .foregroundStyle(Palette.textPrimary)
                    .textSelection(.enabled)
                    .padding(MarkdownMetrics.blockGap)
            }

            if prepared.lines.count > Self.lineCap {
                Button(TextFold.title(isExpanded: showsAllLines, lines: prepared.lines.count)) {
                    showsAllLines.toggle()
                }
                .linkButton()
                .font(Typo.caption)
                .padding(.horizontal, MarkdownMetrics.blockGap)
                .padding(.vertical, Metrics.spacing)
            }
        }
        .background(Palette.surfaceSunken)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.corner))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.corner)
                .strokeBorder(Palette.border, lineWidth: Metrics.outline)
        }
    }

    private func highlighted(_ prepared: CodeBlockPreparation, upTo count: Int) -> AttributedString {
        var output = AttributedString()
        for offset in 0..<count {
            if offset > 0 { output += AttributedString("\n") }
            output += SyntaxCache.attributed(
                line: prepared.lines[offset],
                language: language,
                carry: prepared.carries[offset]
            )
        }
        return output
    }

    private static func displayName(for language: Language) -> String {
        switch language {
        case .plainText: "Plain text"
        case .javascript: "JavaScript"
        case .typescript: "TypeScript"
        case .html: "HTML"
        case .css: "CSS"
        case .json: "JSON"
        case .yaml: "YAML"
        case .toml: "TOML"
        case .sql: "SQL"
        case .xml: "XML"
        case .php: "PHP"
        default: language.rawValue.capitalized
        }
    }
}

private final class CodeBlockPreparationKey: NSObject {
    let code: String
    let language: Language
    private let cachedHash: Int

    init(code: String, language: Language) {
        self.code = code
        self.language = language
        var hasher = Hasher()
        hasher.combine(code)
        hasher.combine(language)
        cachedHash = hasher.finalize()
    }

    override var hash: Int { cachedHash }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? CodeBlockPreparationKey else { return false }
        return cachedHash == other.cachedHash
            && code == other.code
            && language == other.language
    }
}

private final class CodeBlockPreparation {
    let lines: [String]
    let carries: [LexState]

    init(lines: [String], carries: [LexState]) {
        self.lines = lines
        self.carries = carries
    }
}

private enum CodeBlockPreparationCache {
    nonisolated(unsafe) private static let values: NSCache<CodeBlockPreparationKey, CodeBlockPreparation> = {
        let cache = NSCache<CodeBlockPreparationKey, CodeBlockPreparation>()
        cache.countLimit = 0
        cache.totalCostLimit = 8 * 1_024 * 1_024
        return cache
    }()

    @MainActor private static var streamed: (code: String, language: Language, value: CodeBlockPreparation)?

    @MainActor static func prepared(code: String, language: Language, isStreaming: Bool) -> CodeBlockPreparation {
        guard isStreaming else { return settled(code: code, language: language) }
        if let streamed, streamed.code == code, streamed.language == language {
            return streamed.value
        }
        let value = compute(code: code, language: language)
        streamed = (code, language, value)
        return value
    }

    static func settled(code: String, language: Language) -> CodeBlockPreparation {
        let key = CodeBlockPreparationKey(code: code, language: language)
        if let cached = values.object(forKey: key) { return cached }
        let value = compute(code: code, language: language)
        values.setObject(value, forKey: key, cost: code.utf8.count)
        return value
    }

    private static func compute(code: String, language: Language) -> CodeBlockPreparation {
        let lines = code.components(separatedBy: "\n")
        return CodeBlockPreparation(
            lines: lines,
            carries: CarryPass.states(for: lines, language: language)
        )
    }
}

enum CodeBlockPrime {
    static func prepare(code: String, language: Language) {
        _ = CodeBlockPreparationCache.settled(code: code, language: language)
    }
}
