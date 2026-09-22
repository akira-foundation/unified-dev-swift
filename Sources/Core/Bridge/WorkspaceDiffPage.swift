import Foundation

enum WorkspaceDiffPage {
    static let characterLimit = 32_000

    struct Cursor: Equatable {
        var workspaceID: WorkspaceID
        var fingerprint: String
        var offset: Int

        init(workspaceID: WorkspaceID, fingerprint: String, offset: Int) {
            self.workspaceID = workspaceID
            self.fingerprint = fingerprint
            self.offset = offset
        }

        init?(_ raw: String, workspaceID: WorkspaceID) {
            let parts = raw.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 3, parts[0] == workspaceID.rawValue, !parts[1].isEmpty,
                  let offset = Int(parts[2]), offset >= 0 else { return nil }
            self.init(workspaceID: workspaceID, fingerprint: String(parts[1]), offset: offset)
        }

        var rawValue: String { "\(workspaceID.rawValue):\(fingerprint):\(offset)" }
    }

    struct Page: Equatable {
        var text: String
        var offset: Int
        var complete: Bool
        var nextCursor: Cursor?
    }

    struct StaleCursor: Error, Equatable {}

    static func fingerprint(diff: String, path: String?) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        func mix(_ byte: UInt8) {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        (path ?? "").utf8.forEach(mix)
        mix(0)
        diff.utf8.forEach(mix)
        return String(hash, radix: 16)
    }

    static func make(
        diff: String,
        path: String?,
        workspaceID: WorkspaceID,
        cursor: Cursor?,
        limit: Int = characterLimit
    ) throws -> Page {
        let fingerprint = fingerprint(diff: diff, path: path)
        let offset = cursor?.offset ?? 0
        if let cursor {
            guard cursor.fingerprint == fingerprint, cursor.workspaceID == workspaceID,
                  offset <= diff.count else { throw StaleCursor() }
        }
        let rest = diff.dropFirst(offset)
        guard rest.count > limit else {
            return Page(text: String(rest), offset: offset, complete: true, nextCursor: nil)
        }
        var chunk = rest.prefix(limit)
        if let lineEnd = chunk.lastIndex(where: \.isNewline) {
            chunk = chunk[...lineEnd]
        }
        return Page(
            text: String(chunk),
            offset: offset,
            complete: false,
            nextCursor: Cursor(workspaceID: workspaceID, fingerprint: fingerprint, offset: offset + chunk.count)
        )
    }
}
