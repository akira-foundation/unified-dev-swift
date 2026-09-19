import Core

extension TranscriptRow {
    func foldFact(seq: Int? = nil, isFresh: Bool = false) -> TranscriptFold.Fact {
        let settled: Bool
        switch kind {
        case .toolUse: settled = resultPayload != nil
        case .permissionAsk: settled = permissionDecision != nil
        default: settled = true
        }
        return TranscriptFold.Fact(
            seq: seq ?? self.seq,
            kind: kind,
            failed: isError || refusal != nil,
            featured: isQuestion
                || MediaShowRow.isCall(payload) || CodexImageViewRow.isCall(payload),
            drawsNothing: TranscriptNoise.isHidden(self)
                || TranscriptRowInk.drawsNothing(kind: kind, payload: payload),
            settled: settled,
            isFresh: isFresh,
            toolUseID: kind == .toolUse ? refID : nil,
            parentToolUseID: parentToolUseID,
            opensTurn: BackgroundWake.isRow(kind: kind, payload: payload)
        )
    }
}
