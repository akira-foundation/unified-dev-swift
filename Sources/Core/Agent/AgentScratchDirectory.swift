import Foundation

public enum AgentScratchDirectory {
    public static let folderName = "unifieddev-agent-scratch"

    public static func path(in base: String) -> String {
        (base as NSString).appendingPathComponent(folderName)
    }

    public static func make(in base: String) -> String {
        let directory = path(in: base)
        do {
            try FileManager.default.createDirectory(
                atPath: directory, withIntermediateDirectories: true
            )
            return directory
        } catch {
            return base
        }
    }

    public static func current() -> String {
        make(in: NSTemporaryDirectory())
    }
}
