import Foundation

public enum TranscriptCursorSweep {
    public static let positionKey = "spend.cursorSweepPosition"
    public static let readBatch = 256
    public static let sweepBatch = 1_024

    public static func pages(of files: [TranscriptFile]) -> [ArraySlice<TranscriptFile>] {
        stride(from: 0, to: files.count, by: readBatch).map { start in
            files[start..<min(start + readBatch, files.count)]
        }
    }

    public static func vanished(in paths: [String], exists: (String) -> Bool) -> [String] {
        paths.filter { !exists($0) && !isOnMissingVolume($0, exists: exists) }
    }

    static func isOnMissingVolume(_ path: String, exists: (String) -> Bool) -> Bool {
        let components = path.split(separator: "/")
        guard components.count >= 2, components[0] == "Volumes" else { return false }
        return !exists("/Volumes/\(components[1])")
    }

    public static func nextPosition(after paths: [String]) -> String? {
        paths.count < sweepBatch ? nil : paths.last
    }
}
