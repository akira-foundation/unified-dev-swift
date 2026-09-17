import Foundation

public final class SyntaxCacheKey: NSObject {
    private let line: String
    private let language: Language
    private let carry: LexState
    private let cachedHash: Int

    public init(line: String, language: Language, carry: LexState) {
        self.line = line
        self.language = language
        self.carry = carry
        var hasher = Hasher()
        hasher.combine(line)
        hasher.combine(language)
        hasher.combine(carry)
        self.cachedHash = hasher.finalize()
    }

    public override var hash: Int { cachedHash }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? SyntaxCacheKey else { return false }
        return cachedHash == other.cachedHash
            && line.utf8.elementsEqual(other.line.utf8)
            && language == other.language
            && carry == other.carry
    }
}
