import Foundation
import Core

enum TranscriptPresentationCache {
    private static let limit = 8_192

    nonisolated(unsafe) private static let values: NSCache<NSNumber, ToolPresentationBox> = {
        let cache = NSCache<NSNumber, ToolPresentationBox>()
        cache.countLimit = limit
        return cache
    }()

    static func presentation(rowID: Int64, use: AgentToolUse, worktree: String) -> ToolPresentation {
        let key = NSNumber(value: rowID)
        if let cached = values.object(forKey: key) { return cached.value }

        let value = TranscriptPresenter.present(use, worktree: worktree)
        values.setObject(ToolPresentationBox(value), forKey: key)
        return value
    }
}

private final class ToolPresentationBox {
    let value: ToolPresentation

    init(_ value: ToolPresentation) { self.value = value }
}
