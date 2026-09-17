import Foundation

public struct QuickPromptMarkChoice: Sendable, Hashable, Identifiable {
    public let mark: QuickPromptMark
    public let label: String

    public var id: String { mark.stored }

    public init(mark: QuickPromptMark, label: String) {
        self.mark = mark
        self.label = label
    }
}

public struct QuickPromptMarkSection: Sendable, Hashable, Identifiable {
    public let name: String?
    public let choices: [QuickPromptMarkChoice]

    public var id: String { name ?? "" }

    public init(name: String?, choices: [QuickPromptMarkChoice]) {
        self.name = name
        self.choices = choices
    }

    public func rows(across columns: Int) -> [QuickPromptMarkRow] {
        guard columns > 0 else { return [] }
        return stride(from: 0, to: choices.count, by: columns).map {
            QuickPromptMarkRow(choices: Array(choices[$0..<min($0 + columns, choices.count)]))
        }
    }
}

public struct QuickPromptMarkRow: Sendable, Hashable, Identifiable {
    public let choices: [QuickPromptMarkChoice]

    public var id: String { choices.first?.id ?? "" }

    public init(choices: [QuickPromptMarkChoice]) {
        self.choices = choices
    }
}

public enum QuickPromptMarkKind: String, Sendable, Hashable, CaseIterable, Identifiable {
    case icons
    case emoji

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .icons: "Icons"
        case .emoji: "Emojis"
        }
    }
}

public enum QuickPromptMarkCatalog {
    public static let iconSections: [QuickPromptMarkSection] = [
        QuickPromptMarkSection(name: "Writing", choices: symbols([
            "text.alignleft", "text.quote", "pencil", "square.and.pencil", "pencil.and.outline",
            "doc.text", "doc.richtext", "doc.plaintext", "note.text",
            "list.bullet", "list.number", "checklist", "book", "book.closed", "newspaper",
        ])),
        QuickPromptMarkSection(name: "Code and build", choices: symbols([
            "terminal", "chevron.left.forwardslash.chevron.right", "curlybraces", "function",
            "hammer", "wrench.and.screwdriver", "gearshape", "gearshape.2",
            "cpu", "memorychip", "shippingbox", "cube", "command", "bolt",
        ])),
        QuickPromptMarkSection(name: "Tests and checks", choices: symbols([
            "checkmark.seal", "checkmark.circle", "checkmark.shield", "xmark.circle",
            "xmark.octagon", "exclamationmark.triangle", "exclamationmark.octagon", "testtube.2",
            "stethoscope", "waveform.path.ecg", "ladybug", "ant",
        ])),
        QuickPromptMarkSection(name: "Git and review", choices: symbols([
            "arrow.triangle.branch", "arrow.triangle.pull", "arrow.triangle.merge",
            "arrow.triangle.2.circlepath", "arrow.uturn.backward", "clock.arrow.circlepath",
            "tag", "bookmark", "eye", "eyes", "hand.thumbsup", "hand.thumbsdown",
        ])),
        QuickPromptMarkSection(name: "Search and files", choices: symbols([
            "magnifyingglass", "doc.text.magnifyingglass", "folder", "tray.full", "archivebox",
            "externaldrive", "square.stack.3d.up", "map", "binoculars", "paperclip", "camera",
        ])),
        QuickPromptMarkSection(name: "Cleaning up", choices: symbols([
            "trash", "scissors", "paintbrush", "paintbrush.pointed", "wand.and.rays",
            "sparkles", "sparkle", "minus.circle", "bandage",
        ])),
        QuickPromptMarkSection(name: "Shipping", choices: symbols([
            "paperplane", "envelope", "airplane", "globe", "network", "server.rack",
            "icloud.and.arrow.up", "square.and.arrow.up",
            "antenna.radiowaves.left.and.right", "lock", "key",
        ])),
        QuickPromptMarkSection(name: "Asking and thinking", choices: symbols([
            "questionmark.circle", "lightbulb", "brain", "graduationcap", "person", "person.2",
            "bubble.left.and.bubble.right", "hand.raised", "megaphone", "target",
        ])),
        QuickPromptMarkSection(name: "Time and marks", choices: symbols([
            "clock", "timer", "calendar", "hourglass", "flag", "star", "heart", "pin", "bell",
            "chart.bar", "chart.line.uptrend.xyaxis",
        ])),
    ]

    public static let emojiSections: [QuickPromptMarkSection] = [
        QuickPromptMarkSection(name: nil, choices: emoji([
            "\u{1F41B}": "bug", "\u{2705}": "check pass green", "\u{274C}": "cross fail red",
            "\u{26A0}\u{FE0F}": "warning", "\u{1F680}": "rocket ship launch",
            "\u{1F525}": "fire hot", "\u{2728}": "sparkles polish", "\u{1F3AF}": "target aim",
            "\u{1F9EA}": "test tube experiment", "\u{1F50D}": "search look",
            "\u{1F4DD}": "note write memo", "\u{1F4C4}": "page document",
            "\u{1F4DA}": "books docs", "\u{1F9F9}": "broom clean tidy",
            "\u{1F9F0}": "toolbox tools", "\u{1F527}": "wrench fix",
            "\u{1F528}": "hammer build", "\u{2699}\u{FE0F}": "gear settings",
            "\u{1F4E6}": "package box release", "\u{1F6A2}": "ship deploy",
            "\u{1F3D7}\u{FE0F}": "construction building", "\u{26A1}": "lightning fast speed",
            "\u{1F4A1}": "idea lightbulb", "\u{1F914}": "thinking",
            "\u{2753}": "question", "\u{1F4AC}": "comment chat", "\u{1F4E3}": "announce shout",
            "\u{1F440}": "eyes review look", "\u{1F9E0}": "brain think",
            "\u{1F91D}": "handshake agree", "\u{1F64F}": "please thanks",
            "\u{1F389}": "party done celebrate", "\u{1F3A8}": "art design paint",
            "\u{1F331}": "seedling new grow", "\u{1F343}": "leaf green",
            "\u{2615}": "coffee break", "\u{1F552}": "clock time later",
            "\u{1F512}": "lock secure", "\u{1F511}": "key secret",
            "\u{1F4CC}": "pin keep", "\u{1F9CA}": "ice freeze cold",
            "\u{1FA84}": "wand magic", "\u{1F480}": "skull dead danger",
            "\u{1F422}": "turtle slow", "\u{1F501}": "repeat retry again",
            "\u{1F9F5}": "thread string", "\u{1F5D1}\u{FE0F}": "bin delete remove",
            "\u{1F3F7}\u{FE0F}": "label tag", "\u{1F9ED}": "compass explore find",
            "\u{1F4CA}": "chart stats numbers", "\u{1F575}\u{FE0F}": "detective investigate",
            "\u{1F517}": "link url", "\u{1F9EF}": "extinguisher hotfix",
            "\u{1FA79}": "plaster patch fix", "\u{23F1}\u{FE0F}": "stopwatch timing",
            "\u{1F5C2}\u{FE0F}": "files folders",
        ])),
    ]

    public static func sections(_ kind: QuickPromptMarkKind) -> [QuickPromptMarkSection] {
        switch kind {
        case .icons: iconSections
        case .emoji: emojiSections
        }
    }

    public static func kind(of mark: QuickPromptMark) -> QuickPromptMarkKind {
        mark.isEmoji ? .emoji : .icons
    }

    public static let all: [QuickPromptMarkChoice] =
        (iconSections + emojiSections).flatMap(\.choices)

    public static func filtered(_ kind: QuickPromptMarkKind, query: String) -> [QuickPromptMarkSection] {
        let bands = sections(kind)
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return bands }
        return bands.compactMap { section in
            if section.name?.lowercased().contains(needle) == true { return section }
            let kept = section.choices.filter {
                $0.label.contains(needle) || $0.mark.stored.lowercased().contains(needle)
            }
            return kept.isEmpty ? nil : QuickPromptMarkSection(name: section.name, choices: kept)
        }
    }

    public static func stepped(
        _ sections: [QuickPromptMarkSection], from mark: QuickPromptMark?, by step: Int
    ) -> QuickPromptMark? {
        let choices = sections.flatMap(\.choices)
        guard !choices.isEmpty else { return nil }
        guard let mark, let index = choices.firstIndex(where: { $0.mark == mark }) else {
            return step > 0 ? choices.first?.mark : choices.last?.mark
        }
        let next = min(max(index + step, 0), choices.count - 1)
        return choices[next].mark
    }

    public static func settled(
        _ sections: [QuickPromptMarkSection], after mark: QuickPromptMark?
    ) -> QuickPromptMark? {
        let choices = sections.flatMap(\.choices)
        if let mark, choices.contains(where: { $0.mark == mark }) { return mark }
        return choices.first?.mark
    }

    private static func symbols(_ names: [String]) -> [QuickPromptMarkChoice] {
        names.map {
            QuickPromptMarkChoice(
                mark: .symbol($0),
                label: $0.replacingOccurrences(of: ".", with: " ").lowercased()
            )
        }
    }

    private static func emoji(_ entries: KeyValuePairs<String, String>) -> [QuickPromptMarkChoice] {
        entries.map { QuickPromptMarkChoice(mark: .emoji($0.key), label: $0.value) }
    }
}
