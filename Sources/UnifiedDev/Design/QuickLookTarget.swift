import Foundation

enum QuickLookTarget {
    static func url(for path: String) -> URL? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return nil
        }
        guard !isDirectory.boolValue, FileManager.default.isReadableFile(atPath: path) else {
            return nil
        }
        let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size]) as? Int ?? 0
        guard size > 0 else { return nil }

        return URL(fileURLWithPath: path)
    }
}
