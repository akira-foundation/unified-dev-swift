import Foundation

public extension FolderPath {
    static func isFree(_ path: String) -> Bool {
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return !exists(path)
        }
        guard isDirectory.boolValue else { return false }
        return isEmptyDirectory(path)
    }

    static func isEmptyDirectory(_ path: String) -> Bool {
        guard let inside = try? FileManager.default.contentsOfDirectory(atPath: path) else {
            return false
        }
        return inside.allSatisfy { $0 == ".DS_Store" }
    }

    static func exists(_ path: String) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: path)) != nil
    }
}
