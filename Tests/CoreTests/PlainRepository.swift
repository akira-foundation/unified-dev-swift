import Foundation
@testable import Core

struct PlainRepository {
    let path: String

    init() async throws {
        path = TestScratch.unique("plain-repository")
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        try await Shell.check("git", ["init", "-q", "-b", "main"], cwd: path)
        try "hello\n".write(toFile: path + "/README.md", atomically: true, encoding: .utf8)
        try await Shell.check("git", ["add", "-A"], cwd: path)
        try await Shell.check("git", [
            "-c", "user.name=Unified Dev Test", "-c", "user.email=test@unifieddev.local",
            "-c", "commit.gpgsign=false", "commit", "-q", "-m", "Start",
        ], cwd: path)
    }

    func configure(_ arguments: [String]) async throws {
        try await Shell.check("git", ["config"] + arguments, cwd: path)
    }

    func write(_ relative: String, _ contents: String, executable: Bool = false) throws {
        let full = (path as NSString).appendingPathComponent(relative)
        try FileManager.default.createDirectory(
            atPath: (full as NSString).deletingLastPathComponent, withIntermediateDirectories: true
        )
        try contents.write(toFile: full, atomically: true, encoding: .utf8)
        guard executable else { return }
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: full)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(atPath: path)
    }
}
