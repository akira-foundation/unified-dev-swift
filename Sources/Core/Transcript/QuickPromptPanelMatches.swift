import Foundation

public enum QuickPromptPanelRow: Identifiable, Sendable, Hashable {
    case personal(QuickPrompt)
    case project(ProjectQuickPrompt)

    public var id: String {
        switch self {
        case .personal(let prompt): "personal." + prompt.id.rawValue
        case .project(let prompt): "project." + prompt.id
        }
    }

    public var name: String {
        switch self {
        case .personal(let prompt): prompt.resolvedName
        case .project(let prompt): prompt.name
        }
    }
}

public struct QuickPromptPanelMatches: Sendable, Hashable {
    public let query: String
    public let personal: [QuickPrompt]
    public let project: [ProjectQuickPrompt]

    public init(query: String = "", personal: [QuickPrompt] = [], project: [ProjectQuickPrompt] = []) {
        self.query = query
        self.personal = personal
        self.project = project
    }

    public var rows: [QuickPromptPanelRow] {
        personal.map(QuickPromptPanelRow.personal) + project.map(QuickPromptPanelRow.project)
    }

    public var isEmpty: Bool { personal.isEmpty && project.isEmpty }

    public static func ranking(
        personal: [QuickPrompt], project: [ProjectQuickPrompt], query: String, limit: Int = 100
    ) -> QuickPromptPanelMatches {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return QuickPromptPanelMatches(
            query: trimmed,
            personal: QuickPromptMatches.ranked(
                personal, query: trimmed, limit: limit, name: \.resolvedName, text: \.text
            ),
            project: QuickPromptMatches.ranked(
                project, query: trimmed, limit: limit, name: \.name, text: \.text
            )
        )
    }

    public func stepped(from current: QuickPromptPanelRow?, by step: Int) -> QuickPromptPanelRow? {
        let rows = rows
        let held = current.flatMap { current in rows.first { $0.id == current.id } }
        return MenuRows.stepped(from: held, by: step, in: rows)
    }

    public func settled(after current: QuickPromptPanelRow?) -> QuickPromptPanelRow? {
        let rows = rows
        guard let current, let held = rows.first(where: { $0.id == current.id }) else {
            return rows.first
        }
        return held
    }
}
