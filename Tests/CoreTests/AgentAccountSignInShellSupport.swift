import Foundation
@testable import Core

enum SignInShell {
    static let all = ["/bin/sh", "/bin/zsh", "/bin/dash", "/bin/bash"]
        .filter { FileManager.default.isExecutableFile(atPath: $0) }

    static let hostileOpenings = ["", "IFS=:; ", "readonly CLAUDE_X; "]

    static let credentials = LaunchAccountFixture.hostAuth
        + LaunchAccountFixture.credentials
        + LaunchAccountFixture.tokens
        + ["CLAUDE_X"]

    static var dirty: [String: String] {
        var variables = Dictionary(uniqueKeysWithValues: credentials.map { ($0, "inherited") })
        variables["CLAUDE_CONFIG_DIR"] = "/somewhere/else"
        variables["PATH"] = "/usr/bin:/bin"
        return variables
    }

    static var probe: String {
        (credentials + ["CLAUDE_CONFIG_DIR", "PATH"]).map { "\($0)=${\($0)-unset}" }.joined(separator: " ")
    }

    static func reading(of output: String) -> [String: String] {
        Dictionary(uniqueKeysWithValues: output.split(separator: " ").compactMap { pair -> (String, String)? in
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            return parts.count == 2 ? (parts[0], parts[1]) : nil
        })
    }
}
