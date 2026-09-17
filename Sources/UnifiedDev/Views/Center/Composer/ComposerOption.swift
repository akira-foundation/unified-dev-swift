import Core

struct ComposerOption: Identifiable, Hashable {
    var id: String
    var label: String
    var detail: String?

    static let models = [
        ComposerOption(id: "fable", label: "Fable 5.1"),
        ComposerOption(id: "opus", label: "Opus 5"),
        ComposerOption(id: "sonnet", label: "Sonnet 5"),
        ComposerOption(id: "haiku", label: "Haiku 4.5"),
    ]

    static let efforts = [
        ComposerOption(id: "low", label: "Low"),
        ComposerOption(id: "medium", label: "Medium"),
        ComposerOption(id: "high", label: "High"),
        ComposerOption(id: "xhigh", label: "Extra high"),
        ComposerOption(id: "max", label: "Max"),
    ]

    static func adding(_ extras: [String], to options: [ComposerOption]) -> [ComposerOption] {
        var known = Set(options.map(\.id))
        var result = options
        for id in extras {
            let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, known.insert(trimmed).inserted else { continue }
            result.append(ComposerOption(id: trimmed, label: label(for: trimmed, in: options)))
        }
        return result
    }

    static func label(for id: String, in options: [ComposerOption]) -> String {
        if let match = options.first(where: { $0.id == id }) { return match.label }
        guard !id.isEmpty else { return options.first?.label ?? id }
        return titleCased(id)
    }

    static func ranked(_ options: [ComposerOption]) -> [ComposerOption] {
        let byID = Dictionary(options.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ClaudeModelRank.ordered(options.map(\.id)).compactMap { byID[$0] }
    }

    static func titleCased(_ id: String) -> String { ModelLabel.readable(id) }
}
