import Foundation
@testable import Core

extension TempRepo {
    static func clone(of server: TempRepo, named name: String) async throws -> TempRepo {
        let path = TestScratch.unique(name)
        try await Shell.check("git", ["clone", "-q", server.path, path])
        try await Shell.check("git", ["config", "user.email", "test@unifieddev.local"], cwd: path)
        try await Shell.check("git", ["config", "user.name", "Unified Dev Test"], cwd: path)
        try await Shell.check("git", ["config", "commit.gpgsign", "false"], cwd: path)
        return TempRepo(existing: path)
    }
}
