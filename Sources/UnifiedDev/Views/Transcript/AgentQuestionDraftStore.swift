import Observation
import SwiftUI
import Core

@MainActor
enum AgentQuestionCache {
    private static let values: NSCache<NSString, AgentQuestionsBox> = {
        let cache = NSCache<NSString, AgentQuestionsBox>()
        cache.countLimit = 64
        return cache
    }()

    static func questions(in ask: PermissionAsk) -> [AgentQuestion] {
        let key = askKey(ask) as NSString
        if let cached = values.object(forKey: key) { return cached.value }

        let value = AgentQuestionnaire.questions(in: ask.input)
        values.setObject(AgentQuestionsBox(value), forKey: key)
        return value
    }
}

final class AgentQuestionsBox {
    let value: [AgentQuestion]

    init(_ value: [AgentQuestion]) { self.value = value }
}

func askKey(_ ask: PermissionAsk) -> String {
    "\(ask.requestID)\u{1}\(ask.toolUseID)"
}

@MainActor
enum AgentQuestionDraftStore {
    private static var boxes: [String: AgentQuestionDraftBox] = [:]
    private static var ledger = AgentQuestionDraftLedger(limit: 64)

    static func box(for ask: PermissionAsk) -> AgentQuestionDraftBox {
        let key = askKey(ask)
        let box = boxes[key] ?? AgentQuestionDraftBox()

        boxes[key] = box
        ledger.used(key)

        for spare in ledger.dropping(where: { boxes[$0]?.draft.isEmpty ?? true }) {
            boxes.removeValue(forKey: spare)
        }

        return box
    }
}

@MainActor
@Observable
final class AgentQuestionDraftBox {
    var draft = AgentQuestionDraft()
}
