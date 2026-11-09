import Foundation

public enum ComposerDropItem: Sendable, Hashable {
    case folder(String)
    case attachment
    case unasked
}

public struct ComposerDropPlan: Sendable, Hashable {
    public let insertion: String
    public let attachmentIndices: [Int]
    public let omittedItems: Int

    public init(insertion: String, attachmentIndices: [Int], omittedItems: Int = 0) {
        self.insertion = insertion
        self.attachmentIndices = attachmentIndices
        self.omittedItems = omittedItems
    }

    public var writesText: Bool { !insertion.isEmpty }

    public func tookTheDrop(attached: Bool) -> Bool { attached || writesText }

    public var omissionNotice: String? {
        guard omittedItems > 0 else { return nil }
        let verb = omittedItems == 1 ? "was" : "were"
        return "\(Counted.of(omittedItems, "item")) \(verb) left out: a drop adds at most "
            + "\(ComposerFolderDrop.maximumFolders) folders and looks at "
            + "\(ComposerDropQuestions.maximumAsked) items."
    }
}

public enum ComposerFolderDrop {
    public static let maximumFolders = 32
    public static let changedOwnerNotice = "That drop was not added because the conversation changed."

    public static func plan(
        _ items: [ComposerDropItem],
        roots: [String],
        before: String = "",
        after: String = ""
    ) -> ComposerDropPlan {
        var mentions: [String] = []
        var attachments: [Int] = []
        var unasked = 0
        for (index, item) in items.enumerated() {
            switch item {
            case .folder(let path): mentions.append(mention(of: path, roots: roots))
            case .attachment: attachments.append(index)
            case .unasked: unasked += 1
            }
        }
        guard !mentions.isEmpty else {
            return ComposerDropPlan(insertion: "", attachmentIndices: attachments, omittedItems: unasked)
        }
        let (lead, trail) = AttachmentDraft.padding(before: before, after: after)
        return ComposerDropPlan(
            insertion: lead + mentions.prefix(maximumFolders).joined(separator: " ") + trail,
            attachmentIndices: attachments,
            omittedItems: unasked + max(0, mentions.count - maximumFolders)
        )
    }

    public static func insertionRange(
        dropped: NSRange,
        textAtDrop: String,
        textNow: String,
        selection: NSRange
    ) -> NSRange {
        textAtDrop == textNow ? dropped : NSRange(location: NSMaxRange(selection), length: 0)
    }

    public static func isSameDraft(ownerAtDrop: String, ownerNow: String) -> Bool {
        ownerAtDrop == ownerNow
    }

    public static func mention(of folder: String, roots: [String]) -> String {
        for root in roots {
            guard let inside = relative(folder, to: root) else { continue }
            return quoted(inside)
        }
        return quoted(standardised(folder))
    }

    static func relative(_ folder: String, to root: String) -> String? {
        guard !root.isEmpty else { return nil }
        let base = standardised(root)
        let path = standardised(folder)
        guard path != base else { return "." }
        let prefix = base.hasSuffix("/") ? base : base + "/"
        guard path.hasPrefix(prefix) else { return nil }
        return String(path.dropFirst(prefix.count))
    }

    static func quoted(_ path: String) -> String {
        guard needsQuoting(path) else { return path }
        let escaped = path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\"" + escaped + "\""
    }

    static func needsQuoting(_ path: String) -> Bool {
        if path.hasPrefix("-") { return true }
        if path.hasPrefix("/"), !path.dropFirst().contains("/") { return true }
        return path.unicodeScalars.contains { awkward.contains($0) }
    }

    private static let awkward = CharacterSet(charactersIn: "\"'`$&|;<>()[]{}*?!#~\\")
        .union(.whitespacesAndNewlines)
        .union(.controlCharacters)

    private static func standardised(_ path: String) -> String {
        URL(filePath: path).standardized.path
    }
}
