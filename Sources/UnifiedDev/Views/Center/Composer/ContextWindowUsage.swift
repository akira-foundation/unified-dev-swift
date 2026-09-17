import Foundation
import Core

struct ContextWindowUsage: Equatable {
    var used: Int
    var limit: Int

    var fraction: Double {
        limit > 0 ? min(1, Double(used) / Double(limit)) : 0
    }

    var remaining: Int { max(0, limit - used) }

    static let crowdedAt = 0.8

    var isCrowded: Bool { fraction >= Self.crowdedAt }

    @MainActor
    static func latest(in rows: [TranscriptRow]) -> Self? {
        updated(nil, with: rows)
    }

    @MainActor
    static func updated(
        _ held: Self?, with rows: some BidirectionalCollection<TranscriptRow>
    ) -> Self? {
        var used = 0
        var limit = 0

        for row in rows.reversed() {
            guard row.parentToolUseID == nil else { continue }
            switch row.kind {
            case .result where limit == 0:
                if case .result(let result)? = event(of: row) {
                    limit = result.usage.contextTokens
                }
            case .assistantText, .thinking:
                guard used == 0 else { continue }
                switch event(of: row) {
                case .assistantText(let block)?, .thinking(let block)?:
                    used = block.usage.contextUsedTokens
                default:
                    break
                }
            default:
                continue
            }
            if used > 0, limit > 0 { break }
        }

        if used == 0 { used = held?.used ?? 0 }
        if limit == 0 { limit = held?.limit ?? 0 }
        guard used > 0, limit > 0 else { return nil }
        return Self(used: used, limit: limit)
    }

    @MainActor
    private static func event(of row: TranscriptRow) -> AgentEvent? {
        TranscriptEventCache.event(rowID: row.id, payload: row.payload)
    }

    static func format(_ tokens: Int) -> String {
        switch tokens {
        case 1_000_000...:
            "\((Double(tokens) / 1_000_000).formatted(.number.precision(.fractionLength(1))))M"
        case 1_000...:
            "\((Double(tokens) / 1_000).formatted(.number.precision(.fractionLength(1))))k"
        default:
            "\(tokens)"
        }
    }

    static func percent(_ fraction: Double) -> String {
        (fraction).formatted(.percent.precision(.fractionLength(0)))
    }

    struct Reading: Equatable {
        var percent: String
        var spoken: String
    }

    var reading: Reading {
        Reading(
            percent: Self.percent(fraction),
            spoken: "\(Self.percent(fraction)) used, "
                + "\(Self.format(used)) of \(Self.format(limit)) tokens"
                + (isCrowded ? ", filling up" : "")
        )
    }
}
