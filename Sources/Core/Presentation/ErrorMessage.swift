import Foundation

public extension Error {
    var readableMessage: String {
        if !(type(of: self) is AnyClass), let described = (self as Any) as? CustomStringConvertible {
            return Self.asSentence(described.description)
        }
        if let localized = self as? LocalizedError, let description = localized.errorDescription {
            return Self.asSentence(description)
        }

        let cocoa = self as NSError
        let isPlaceholder = cocoa.localizedDescription.contains("(\(cocoa.domain) error \(cocoa.code)")
        if !isPlaceholder, !cocoa.localizedDescription.isEmpty {
            return Self.asSentence(cocoa.localizedDescription)
        }

        return String(describing: self)
    }

    private static func asSentence(_ message: String) -> String {
        var trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "Something went wrong." }

        if first.isLowercase, first.isLetter {
            trimmed.replaceSubrange(trimmed.startIndex...trimmed.startIndex, with: first.uppercased())
        }
        if let last = trimmed.last, !".!?:".contains(last) {
            trimmed.append(".")
        }
        return trimmed
    }
}
