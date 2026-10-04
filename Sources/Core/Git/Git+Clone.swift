import Foundation

public extension Git {
    static func clone(
        _ remote: String,
        into destination: String,
        timeout: Duration? = nil
    ) async throws {
        try validate(remote: remote)
        try validate(ref: destination, label: "destination")
        let parent = (destination as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: parent, withIntermediateDirectories: true
        )
        let arguments = ["clone", "--progress", "--", remote, destination]
        let result = try await run(arguments, in: parent, timeout: timeout)
        guard result.ok else {
            throw error(arguments, result.status, result.stderr, result.stdout)
        }
    }

    internal static func validate(remote: String) throws {
        guard !remote.isEmpty, !remote.hasPrefix("-"), !remote.contains("\0") else {
            throw ShellError(
                command: "git clone",
                status: 128,
                stderr: "refusing to clone \(remote.isEmpty ? "an empty address" : "'\(remote)'")"
            )
        }
        if let helper = CloneTarget.transportHelper(in: remote) {
            throw ShellError(
                command: "git clone",
                status: 128,
                stderr: "refusing to clone through the '\(helper)' transport helper"
            )
        }
    }
}
