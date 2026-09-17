import Foundation

public enum WorkspaceFileSearch {
    public static func paths(in directory: String) async throws -> [String] {
        let result = try await Shell.run(
            "git", ["ls-files", "-z", "--cached", "--others", "--exclude-standard"],
            cwd: directory, timeout: .seconds(10)
        )
        return Array(Set(result.stdout.split(separator: "\0").map(String.init))).sorted()
    }
}
