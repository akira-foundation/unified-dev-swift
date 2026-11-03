import Core

extension Collection<TranscriptRow> {
    var hookRefusedCalls: Set<String> {
        ToolRefusal.hookRefusedCalls(lazy.map { (refID: $0.refID, refusal: $0.refusal) })
    }
}
