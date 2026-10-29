import Foundation

public struct AgentAccountCreation: Sendable, Hashable {
    public let provider: AgentKind
    public let label: String
    public let id: AgentAccountID
    public let directory: URL

    public var home: AgentAccountHome {
        AgentAccountHome(provider: provider, id: id, directory: directory, isDefault: false, label: label)
    }

    public static func plan(
        provider: AgentKind,
        label: String,
        existing: [AgentAccountID],
        support: URL
    ) -> AgentAccountCreation {
        let id = identifier(for: label, avoiding: existing)
        let directory = AgentAccountHomes.directory(for: id, provider: provider, support: support)
        return AgentAccountCreation(provider: provider, label: label, id: id, directory: directory)
    }

    public static func settled(
        _ plan: AgentAccountCreation,
        identity: Data?,
        credential: Data?,
        report: AgentAccountLiveness.CliReport,
        codexStorageMode: CodexAuthStorageMode
    ) -> AgentAccountStanding? {
        guard report != .claimsNoSession else { return nil }
        let home = plan.home
        let read = AgentAccountIdentity.read(home, identity: identity, credential: credential)
        guard report == .claimsSession || !read.isEmpty else { return nil }
        return AgentAccountStanding(
            home: home,
            identity: read,
            cliReport: report,
            isolationDoubt: AgentAccountRoster.isolationDoubt(for: plan.provider, codexStorageMode: codexStorageMode)
        )
    }

    public static let maxLabelLength = 60

    public static func cleanLabel(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : String(trimmed.prefix(maxLabelLength))
    }

    public static func occupiedIDs(support: URL) -> [AgentAccountID] {
        let root = AgentAccountHomes.root(support: support)
        let providers = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        return providers.flatMap { provider -> [AgentAccountID] in
            let names = (try? FileManager.default.contentsOfDirectory(
                atPath: root.appending(path: provider, directoryHint: .isDirectory).path
            )) ?? []
            return names.map(AgentAccountID.init)
        }
    }

    public var directoryExists: Bool {
        FileManager.default.fileExists(atPath: directory.path)
    }

    @discardableResult
    public func discardUnusedDirectory(existedBefore: Bool) -> Bool {
        guard !existedBefore, directoryExists else { return false }
        return (try? FileManager.default.removeItem(at: directory)) != nil
    }

    public static func prepareDirectory(of home: AgentAccountHome) throws {
        try FileManager.default.createDirectory(
            at: home.directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }

    public static func signInCommand(
        executable: String,
        provider: AgentKind,
        account: AgentAccountHome?,
        directory: String
    ) -> String {
        guard let account else {
            return TerminalLaunchScript.shellCommand(
                directory: directory,
                executable: executable,
                arguments: provider.loginArguments
            )
        }
        return TerminalLaunchScript.shellCommand(
            directory: directory,
            executable: "/usr/bin/env",
            arguments: AgentAccountEnvironment.shellUnsets
                + AgentAccountEnvironment.shellAssignments(for: account)
                + [executable] + provider.loginArguments
        )
    }

    static func identifier(for label: String, avoiding existing: [AgentAccountID]) -> AgentAccountID {
        let taken = Set(existing.map { $0.rawValue.lowercased() })
        let base = slug(of: label)
        if !taken.contains(base) { return AgentAccountID(base) }
        var number = 2
        while taken.contains(suffixed(base, with: number)) { number += 1 }
        return AgentAccountID(suffixed(base, with: number))
    }

    private static func suffixed(_ base: String, with number: Int) -> String {
        let suffix = "-\(number)"
        let room = String(base.prefix(maxIdentifierLength - suffix.count))
        let trimmed = room.hasSuffix("-") ? String(room.dropLast()) : room
        return trimmed + suffix
    }

    static let maxIdentifierLength = 40

    static func slug(of label: String) -> String {
        let folded = label.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        var result = ""
        var pendingSeparator = false
        for scalar in folded.unicodeScalars {
            let isWord = scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar))
            if isWord {
                if pendingSeparator, !result.isEmpty { result.append("-") }
                pendingSeparator = false
                result.append(Character(scalar))
            } else {
                pendingSeparator = true
            }
        }
        let trimmed = String(result.lowercased().prefix(maxIdentifierLength))
        let stripped = trimmed.hasSuffix("-") ? String(trimmed.dropLast()) : trimmed
        return stripped.isEmpty ? "account" : stripped
    }
}
