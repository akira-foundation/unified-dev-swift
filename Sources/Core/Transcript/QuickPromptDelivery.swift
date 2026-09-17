import Foundation

public enum QuickPromptDelivery: Equatable, Sendable, CaseIterable {
    case compose
    case send
    case composeInNewChat
    case sendInNewChat

    public init(sendsImmediately: Bool, opensNewChat: Bool) {
        switch (sendsImmediately, opensNewChat) {
        case (false, false): self = .compose
        case (true, false): self = .send
        case (false, true): self = .composeInNewChat
        case (true, true): self = .sendInNewChat
        }
    }

    public init(_ prompt: QuickPrompt) {
        self.init(
            sendsImmediately: prompt.sendsImmediately, opensNewChat: prompt.opensNewChat
        )
    }

    public static func decided(
        for prompt: QuickPrompt, canSend: Bool, canOpenNewChat: Bool
    ) -> QuickPromptDelivery {
        switch QuickPromptDelivery(prompt) {
        case .compose:
            return .compose
        case .send:
            return canSend ? .send : .compose
        case .composeInNewChat:
            return canOpenNewChat ? .composeInNewChat : .compose
        case .sendInNewChat:
            guard canOpenNewChat else { return .compose }
            return canSend ? .sendInNewChat : .composeInNewChat
        }
    }

    public var sends: Bool { self == .send || self == .sendInNewChat }

    public var opensNewChat: Bool { self == .composeInNewChat || self == .sendInNewChat }

    public var sentence: String? {
        switch self {
        case .compose:
            nil
        case .send:
            "Sent as soon as you choose it, along with anything already typed in the composer."
        case .composeInNewChat:
            "A new chat tab opens with the words waiting in its composer. Nothing is sent."
        case .sendInNewChat:
            "A new chat tab opens and the words are sent in it straight away."
        }
    }
}
