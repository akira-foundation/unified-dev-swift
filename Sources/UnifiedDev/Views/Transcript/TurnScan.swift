import Foundation
import Core

enum TurnScan {
    private static let scanLimit = 400

    static func files(rows: [TranscriptRow], endingAt seq: Int) -> [TurnFile] {
        guard let end = position(of: seq, in: rows) else { return [] }

        var totals: [String: TurnFile] = [:]
        var order: [String] = []
        var index = end - 1
        var scanned = 0

        while index >= 0, scanned < scanLimit {
            let row = rows[index]
            if row.kind == .result { break }
            if row.kind == .toolUse {
                absorb(row, into: &totals, order: &order)
            }
            index -= 1
            scanned += 1
        }

        return order.reversed().compactMap { totals[$0] }
    }

    private static func absorb(_ row: TranscriptRow, into totals: inout [String: TurnFile], order: inout [String]) {
        guard case .toolUse(let use)? = AgentEvent.decode(line: String(decoding: row.payload, as: UTF8.self)) else {
            return
        }

        if case .fileChange(let change)? = CodexTranslation.item(in: use.input) {
            for update in change.changes {
                merge(path: update.path, added: update.addedLines, removed: update.removedLines,
                      into: &totals, order: &order)
            }
            return
        }

        var added = 0
        var removed = 0
        let path: String

        switch use.name {
        case "Write":
            path = use.input["file_path"]?.stringValue ?? ""
            added = ToolPresenter.lineCount(use.input["content"]?.stringValue ?? "")

        case "Edit":
            path = use.input["file_path"]?.stringValue ?? ""
            added = ToolPresenter.lineCount(use.input["new_string"]?.stringValue ?? "")
            removed = ToolPresenter.lineCount(use.input["old_string"]?.stringValue ?? "")

        case "MultiEdit":
            path = use.input["file_path"]?.stringValue ?? ""
            for edit in use.input["edits"]?.arrayValue ?? [] {
                added += ToolPresenter.lineCount(edit["new_string"]?.stringValue ?? "")
                removed += ToolPresenter.lineCount(edit["old_string"]?.stringValue ?? "")
            }

        case "NotebookEdit":
            path = use.input["notebook_path"]?.stringValue ?? ""
            added = ToolPresenter.lineCount(use.input["new_source"]?.stringValue ?? "")

        default:
            return
        }

        merge(path: path, added: added, removed: removed, into: &totals, order: &order)
    }

    private static func merge(
        path: String,
        added: Int,
        removed: Int,
        into totals: inout [String: TurnFile],
        order: inout [String]
    ) {
        guard !path.isEmpty else { return }

        if var existing = totals[path] {
            existing.additions += added
            existing.deletions += removed
            totals[path] = existing
        } else {
            totals[path] = TurnFile(path: path, additions: added, deletions: removed)
            order.append(path)
        }
    }

    private static func position(of seq: Int, in rows: [TranscriptRow]) -> Int? {
        var low = 0
        var high = rows.count - 1
        while low <= high {
            let middle = (low + high) / 2
            if rows[middle].seq == seq { return middle }
            if rows[middle].seq < seq { low = middle + 1 } else { high = middle - 1 }
        }
        return nil
    }
}

@MainActor
enum TurnScanCache {
    private static let limit = 512

    private static let values: NSCache<NSNumber, TurnFilesBox> = {
        let cache = NSCache<NSNumber, TurnFilesBox>()
        cache.countLimit = limit
        return cache
    }()

    private static let snapshots: NSCache<NSString, TurnFilesBox> = {
        let cache = NSCache<NSString, TurnFilesBox>()
        cache.countLimit = limit
        return cache
    }()

    static func files(snapshotID: GitSnapshotID) -> [TurnFile]? {
        snapshots.object(forKey: snapshotID.rawValue as NSString)?.value
    }

    static func remember(_ files: [TurnFile], snapshotID: GitSnapshotID) {
        snapshots.setObject(TurnFilesBox(files), forKey: snapshotID.rawValue as NSString)
    }

    static func files(rowID: Int64) -> [TurnFile]? {
        values.object(forKey: NSNumber(value: rowID))?.value
    }

    static func remember(_ files: [TurnFile], rowID: Int64) {
        values.setObject(TurnFilesBox(files), forKey: NSNumber(value: rowID))
    }
}

private final class TurnFilesBox {
    let value: [TurnFile]

    init(_ value: [TurnFile]) { self.value = value }
}
