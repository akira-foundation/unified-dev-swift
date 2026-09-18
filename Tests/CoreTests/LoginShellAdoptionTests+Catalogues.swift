import Foundation
import Testing
@testable import Core

private func executableTheProbeInstalls() -> String {
    let path = TestScratch.unique("login-shell-cli")
    LoginShellPath.install {
        try? await Task.sleep(for: .milliseconds(400))
        FileManager.default.createFile(
            atPath: path, contents: Data("#!/bin/sh\necho 1.0.0\n".utf8), attributes: [.posixPermissions: 0o755]
        )
        return []
    }
    return path
}

extension LoginShellAdoptionTests {
    @Test("an agent CLI only the login shell can see is detected on the first look")
    func detectionWaitsForTheProbe() async {
        let executable = executableTheProbeInstalls()
        defer { LoginShellPath.forget() }

        LoginShellPath.begin()
        let status = await AgentCatalog(overrides: [.grok: executable]).status(for: .grok)

        #expect(status.connection != .notInstalled)
    }

    @Test("the installed agent list waits for the login shell before it looks")
    func installedKindsWaitForTheProbe() async {
        let executable = executableTheProbeInstalls()
        defer { LoginShellPath.forget() }

        LoginShellPath.begin()
        let installed = await AgentCatalog.installedKinds(overrides: [.grok: executable])

        #expect(installed.contains(.grok))
    }
}
