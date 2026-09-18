import Foundation
import Testing
@testable import Core

@Suite("Finding an executable on a PATH that can change", .scratchDirectory)
struct ShellResolutionTests {
    private func directoryHolding(_ name: String, label: String) throws -> String {
        let folder = TestScratch.unique(label)
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        let tool = (folder as NSString).appendingPathComponent(name)
        try "#!/bin/sh\n".write(toFile: tool, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tool)
        return folder
    }

    @Test("a PATH that changed is searched again rather than answered from the last one")
    func aChangedPathIsSearchedAgain() throws {
        let name = "probe-tool-" + UUID().uuidString
        let old = try directoryHolding(name, label: "resolution-old")
        let new = try directoryHolding(name, label: "resolution-new")

        let first = Shell.resolve(name, in: old)
        let second = Shell.resolve(name, in: "\(new):\(old)")

        #expect(first == (old as NSString).appendingPathComponent(name))
        #expect(second == (new as NSString).appendingPathComponent(name))
    }

    @Test("a remembered executable that has gone is not answered again")
    func aRememberedExecutableThatHasGoneIsNotAnsweredAgain() throws {
        let name = "probe-tool-" + UUID().uuidString
        let folder = try directoryHolding(name, label: "resolution-stale")
        let tool = (folder as NSString).appendingPathComponent(name)

        let first = Shell.resolve(name, in: folder)
        try FileManager.default.removeItem(atPath: tool)

        #expect(first == tool)
        #expect(Shell.resolve(name, in: folder) == nil)
    }
}
