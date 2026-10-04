import Foundation

public extension FolderPath {
    static func hasContents(_ path: String) -> Bool {
        let manager = FileManager.default
        var isDirectory = ObjCBool(false)
        guard manager.fileExists(atPath: path, isDirectory: &isDirectory) else { return false }
        guard isDirectory.boolValue else { return true }
        let inside = (try? manager.contentsOfDirectory(atPath: path)) ?? []
        return inside.contains { $0 != ".DS_Store" }
    }
}
