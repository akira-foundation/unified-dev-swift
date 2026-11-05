import AppKit
import Core

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

final class CodeBlockPreparation {
    let lines: [String]
    let carries: [LexState]

    init(lines: [String], carries: [LexState]) {
        self.lines = lines
        self.carries = carries
    }
}

enum CodeBlockPreparationCache {
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
