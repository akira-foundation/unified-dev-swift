import Foundation

public enum CanvasExportNames {
    public static let directoryExtension = "export"
    public static let fileExtension = "png"
    public static let longestSlugBytes = 64
    public static let fallbackSlug = "frame"

    public static func slideOrder(_ frames: [CanvasFrame]) -> [CanvasFrame] {
        frames.enumerated().sorted { first, second in
            let (one, two) = (first.element.rect.origin, second.element.rect.origin)
            if one.x != two.x { return one.x < two.x }
            if one.y != two.y { return one.y < two.y }
            return first.offset < second.offset
        }.map(\.element)
    }

    public static func files(for frames: [CanvasFrame], document: String) -> [CanvasFrameID: String] {
        let ordered = slideOrder(frames)
        let width = max(2, String(ordered.count).count)
        let fallback = slug(of: document, fallback: fallbackSlug)
        var names: [CanvasFrameID: String] = [:]
        for (index, frame) in ordered.enumerated() {
            let number = String(index + 1)
            let padded = String(repeating: "0", count: width - number.count) + number
            names[frame.id] = "\(padded)-\(slug(of: frame.name, fallback: fallback)).\(fileExtension)"
        }
        return names
    }

    public static func directoryName(forDocumentAt path: String) -> String {
        let base = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        return "\(slug(of: base, fallback: "canvas")).\(directoryExtension)"
    }

    public static func isExportedFile(_ name: String) -> Bool {
        guard name.hasSuffix(".\(fileExtension)") else { return false }
        let digits = name.prefix { $0.isASCII && $0.isNumber }
        guard digits.count >= 2 else { return false }
        return name.dropFirst(digits.count).hasPrefix("-")
    }

    static func slug(of name: String, fallback: String) -> String {
        var kept = ""
        var lastWasSeparator = true
        for scalar in name.precomposedStringWithCanonicalMapping.lowercased().precomposedStringWithCanonicalMapping.unicodeScalars {
            if isLetterOrNumber(scalar) || (isMark(scalar) && !lastWasSeparator) {
                kept.unicodeScalars.append(scalar)
                lastWasSeparator = false
                continue
            }
            if !lastWasSeparator { kept.append("-") }
            lastWasSeparator = true
        }
        let trimmed = limited(kept).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? fallback : trimmed
    }

    private static func limited(_ slug: String) -> String {
        var result = ""
        var bytes = 0
        for character in slug {
            let size = String(character).utf8.count
            guard bytes + size <= longestSlugBytes else { break }
            result.append(character)
            bytes += size
        }
        return result
    }

    private static func isLetterOrNumber(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .decimalNumber, .letterNumber, .otherNumber: true
        default: false
        }
    }

    private static func isMark(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .spacingMark: true
        default: false
        }
    }
}
