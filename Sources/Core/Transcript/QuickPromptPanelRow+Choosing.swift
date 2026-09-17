import Foundation

extension QuickPromptPanelRow {
    public var text: String {
        switch self {
        case .personal(let prompt): prompt.text
        case .project(let prompt): prompt.text
        }
    }

    public var symbol: String {
        switch self {
        case .personal(let prompt): prompt.symbol
        case .project(let prompt): prompt.symbol
        }
    }

    public var secondLine: String? {
        switch self {
        case .personal(let prompt): prompt.hasSeparatePreview ? prompt.preview : nil
        case .project(let prompt): prompt.preview
        }
    }

    public var chatTitle: String? {
        switch self {
        case .personal(let prompt): prompt.chatTitle
        case .project(let prompt): prompt.chatTitle
        }
    }

    public var isEditable: Bool {
        if case .personal = self { return true }
        return false
    }

    public func delivery(canSend: Bool, canOpenNewChat: Bool) -> QuickPromptDelivery {
        switch self {
        case .personal(let prompt):
            QuickPromptDelivery.decided(for: prompt, canSend: canSend, canOpenNewChat: canOpenNewChat)
        case .project(let prompt):
            prompt.delivery(canOpenNewChat: canOpenNewChat)
        }
    }

    public var accessibilityValue: String {
        switch self {
        case .personal(let prompt):
            return [prompt.preview, QuickPromptDelivery(prompt).sentence]
                .compactMap { $0 }
                .joined(separator: ". ")
        case .project(let prompt):
            return [prompt.preview, "From this project", prompt.delivery(canOpenNewChat: true).sentence]
                .compactMap { $0 }
                .joined(separator: ". ")
        }
    }
}
