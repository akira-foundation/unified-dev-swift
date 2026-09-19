import Foundation
import Core

enum TranscriptPrime {
    static let width = 4

    static func run(rows: [TranscriptRow], worktree: String, unreadSeq: Int?) async {
        guard !rows.isEmpty else { return }
        let unread = unreadSeq.flatMap {
            TranscriptWindow.index(ofSeqAtOrAfter: $0, in: rows.lazy.map(\.seq))
        }
        let window = TranscriptWindow.settling(
            from: .opening(
                rowCount: rows.count,
                tailStart: TranscriptTail.start(in: rows.lazy.map(\.kind)),
                mustReach: unread
            ),
            rowCount: rows.count
        )

        await withTaskGroup(of: Void.self) { group in
            var started = 0
            for index in window.indices(outwardFrom: unread ?? rows.count - 1) {
                if started >= width { _ = await group.next() }
                let row = rows[index]
                group.addTask { prime(row, worktree: worktree) }
                started += 1
            }
        }
    }

    private static func prime(_ row: TranscriptRow, worktree: String) {
        switch row.kind {
        case .user, .error:
            _ = TranscriptEventCache.json(rowID: row.id, payload: row.payload)
        case .notice, .suggestion:
            break
        default:
            guard let event = TranscriptEventCache.event(rowID: row.id, payload: row.payload) else {
                return
            }
            switch event {
            case .assistantText(let block):
                prose(block.text)
            case .toolUse(let use):
                _ = TranscriptPresentationCache.presentation(
                    rowID: row.id, use: use, worktree: worktree
                )
            default:
                break
            }
        }
    }

    private static func prose(_ text: String) {
        guard !text.isEmpty else { return }
        fences(in: MarkdownPrime.blocks(of: text))
    }

    private static func fences(in blocks: [MarkdownBlock]) {
        for block in blocks {
            switch block {
            case .codeBlock(let code, let language, _):
                CodeBlockPrime.prepare(code: code, language: language)
            case .blockQuote(let inner):
                fences(in: inner)
            case .bulletList(let items, _), .numberedList(_, let items, _):
                for item in items { fences(in: item) }
            default:
                break
            }
        }
    }
}
