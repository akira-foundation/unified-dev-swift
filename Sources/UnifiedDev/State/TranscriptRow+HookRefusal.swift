import Core

extension Collection<TranscriptRow> {
    var hookRefusedCalls: Set<String> {
        Set(lazy.filter { $0.refusal == .hookRefused }.compactMap(\.refID))
    }
}
