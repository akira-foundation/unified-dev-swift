import Foundation
import Core

enum TranscriptNoise {
    private static let probeLength = 256
    private static let hookMarker = Data("\"hook_".utf8)

    static func isHidden(_ row: TranscriptRow) -> Bool {
        if row.kind == .notice { return true }
        guard row.kind == .system else { return false }
        return row.payload.prefix(probeLength).range(of: hookMarker) != nil
    }
}
