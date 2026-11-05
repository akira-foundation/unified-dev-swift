import Foundation

extension Store {
    private struct HandoffReading: Sendable {
        struct Source: Sendable {
            var id: SessionID
            var rows: [Message]
            var agent: AgentKind
        }

        var rows: [Message]
        var agent: AgentKind?
        var source: Source?
    }

    func handoffPrompt(
        _ text: String, session: Session, deliveredSeq: Int?, workspacePath: String, contextWindow: Int?
    ) async throws -> String {
        guard try handoffIsDue(sessionID: session.id, deliveredSeq: deliveredSeq) else { return text }
        var worktree: ConversationHandoff.Worktree?
        if let workspaceID = session.workspaceID, let workspace = try workspace(id: workspaceID) {
            worktree = await HandoffWorktree.read(path: workspacePath, base: workspace.baseBranch)
        }
        return try await handoffTurn(
            text, sessionID: session.id, deliveredSeq: deliveredSeq,
            worktree: worktree, contextWindow: contextWindow
        )
    }

    @concurrent public nonisolated func handoffTurn(
        _ text: String, sessionID: SessionID, deliveredSeq: Int?,
        worktree: ConversationHandoff.Worktree?, contextWindow: Int?
    ) async throws -> String {
        guard let reading = try await handoffReading(sessionID: sessionID, deliveredSeq: deliveredSeq) else { return text }
        let budget = ConversationHandoff.budget(contextWindow: contextWindow)
        let own = { (room: Int, worktree: ConversationHandoff.Worktree?) in
            reading.agent.flatMap {
                ConversationHandoff.text(messages: reading.rows, worktree: worktree, chatID: sessionID, budget: room, agent: $0)
            }
        }
        guard let source = reading.source else {
            return own(budget, worktree).map { $0 + "\n\n" + text } ?? text
        }
        let firstOwn = own(budget / 2, worktree)
        let seeded = ConversationHandoff.text(
            messages: source.rows,
            worktree: firstOwn == nil ? worktree : nil,
            chatID: source.id,
            budget: budget - (firstOwn?.count ?? 0),
            agent: source.agent
        )
        return [seeded, own(budget - (seeded?.count ?? 0), worktree), text].compactMap(\.self).joined(separator: "\n\n")
    }

    private func handoffReading(sessionID: SessionID, deliveredSeq: Int?) throws -> HandoffReading? {
        guard try handoffIsDue(sessionID: sessionID, deliveredSeq: deliveredSeq),
              let segment = try activeSegment(sessionID: sessionID) else { return nil }
        let rows = try handoffRows(sessionID: sessionID, afterSeq: segment.cursorSeq, excludingSeq: deliveredSeq)
        let source = try pendingSourceRead(sessionID: sessionID).flatMap { pending in
            try session(id: pending.id).map { origin in
                HandoffReading.Source(
                    id: pending.id,
                    rows: try handoffRows(
                        sessionID: pending.id, afterSeq: -1, excludingSeq: nil, throughSeq: pending.throughSeq
                    ),
                    agent: origin.agentKind
                )
            }
        }
        return HandoffReading(
            rows: rows,
            agent: try HandoffMark.lastLeavingAgent(in: rows) ?? session(id: sessionID)?.agentKind,
            source: source
        )
    }
}
