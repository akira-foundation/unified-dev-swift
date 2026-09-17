import Foundation

public enum ChatFace: Hashable, Sendable {
    case system
    case serif
    case family(String)
}

public struct ChatFontFace: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let summary: String
    public let face: ChatFace

    public init(id: String, title: String, summary: String, face: ChatFace) {
        self.id = id
        self.title = title
        self.summary = summary
        self.face = face
    }
}

public enum ChatFontCatalogue {
    public static let defaultsKey = "chat.font"

    public static let standardID = "system"

    public static let curated: [ChatFontFace] = [
        ChatFontFace(
            id: standardID,
            title: "System",
            summary: "San Francisco, the face the rest of macOS is set in. Drawn for labels and controls.",
            face: .system
        ),
        ChatFontFace(
            id: "reading",
            title: "Reading",
            summary: "New York, Apple's serif companion to San Francisco, drawn for paragraphs.",
            face: .serif
        ),
        ChatFontFace(
            id: "Charter",
            title: "Book",
            summary: "Charter, a book face that keeps its shape at small sizes and sets a little lighter.",
            face: .family("Charter")
        ),
        ChatFontFace(
            id: "Verdana",
            title: "Legible",
            summary: "Verdana, the widest letterforms and the largest x-height, at the cost of a longer line.",
            face: .family("Verdana")
        ),
    ]

    private static let legacyIDs = ["book": "Charter", "legible": "Verdana"]

    public static func canonicalID(_ stored: String?) -> String {
        let trimmed = stored?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return standardID }
        return legacyIDs[trimmed] ?? trimmed
    }

    public static func resolve(_ stored: String?, installed: Set<String>) -> ChatFace {
        let id = canonicalID(stored)
        if let recommended = recommendation(for: id) {
            guard case .family(let name) = recommended.face else { return recommended.face }
            return installed.contains(name) ? recommended.face : .system
        }
        return installed.contains(id) ? .family(id) : .system
    }

    public static func recommendation(for stored: String?) -> ChatFontFace? {
        let id = canonicalID(stored)
        return curated.first { $0.id == id }
    }

    public static func summary(for stored: String?, installed: Set<String>) -> String {
        let id = canonicalID(stored)
        if let recommended = recommendation(for: id) {
            guard case .family(let name) = recommended.face, !installed.contains(name) else {
                return recommended.summary
            }
            return missingSummary(name)
        }
        guard installed.contains(id) else { return missingSummary(id) }
        return "\(id), one of the fonts installed on this Mac."
    }

    private static func missingSummary(_ name: String) -> String {
        "\(name) is not installed on this Mac. The conversation is set in San Francisco until you "
            + "choose another face."
    }

    public static func families(from available: [String]) -> [String] {
        var seen = Set(curated.map(\.id))
        var result: [String] = []
        for family in available {
            let name = family.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isSelectable(name), seen.insert(name).inserted else { continue }
            result.append(name)
        }
        return result.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    public static func families(from available: [String], keeping selected: String?) -> [String] {
        let offered = families(from: available)
        let id = canonicalID(selected)
        guard !curated.contains(where: { $0.id == id }), !offered.contains(id) else { return offered }
        return offered + [id]
    }

    private static func isSelectable(_ name: String) -> Bool {
        guard !name.isEmpty, !name.hasPrefix(".") else { return false }
        let symbolic = ["Emoji", "Dingbat", "Ornament", "Symbols", "Wingdings", "Webdings", "Braille"]
        guard !symbolic.contains(where: { name.localizedCaseInsensitiveContains($0) }) else { return false }
        return name.caseInsensitiveCompare("Symbol") != .orderedSame
    }

    public static func inlineCodeScale(faceXHeight: Double, monoXHeight: Double) -> Double {
        guard faceXHeight > 0, monoXHeight > 0 else { return 1 }
        let ratio = (faceXHeight / monoXHeight * 100).rounded() / 100
        return min(1, max(0.8, ratio))
    }
}
