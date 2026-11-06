import Foundation

public struct AgentAccountPanel: Sendable, Equatable {
    public static let unknown = "unknown"

    public struct Field: Sendable, Equatable, Identifiable {
        public let label: String
        public let value: String

        public var id: String { label }
        public var isKnown: Bool { value != AgentAccountPanel.unknown }
    }

    public struct Row: Sendable, Equatable, Identifiable {
        public let id: AgentAccountID
        public let home: AgentAccountHome
        public let title: String
        public let fields: [Field]
        public let note: String?
        public let warns: Bool
        public let removal: AgentAccountRemoval.Warning?
        public let isUnfinished: Bool

        public var isDefault: Bool { home.isDefault }
    }

    public let provider: AgentKind
    public let rows: [Row]
    public let offer: AgentAccountOffer

    public static func make(
        provider: AgentKind,
        standings: [AgentAccountStanding],
        orphans: [AgentAccountHome] = [],
        codexStorageMode: CodexAuthStorageMode,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> AgentAccountPanel {
        AgentAccountPanel(
            provider: provider,
            rows: standings.filter { $0.home.provider == provider }.map {
                row(for: $0, among: standings, locale: locale, timeZone: timeZone)
            } + orphans.filter { $0.provider == provider }.map(unfinishedRow),
            offer: AgentAccountOffer.make(for: provider, codexStorageMode: codexStorageMode)
        )
    }

    static func unfinishedRow(for home: AgentAccountHome) -> Row {
        let title = home.directory.lastPathComponent
        return Row(
            id: home.id,
            home: home,
            title: title,
            fields: [Field(label: "Session", value: "Sign-in did not finish")],
            note: "Unified Dev never added this account, because its sign-in did not finish. The folder is still on this Mac.",
            warns: true,
            removal: AgentAccountRemoval.warningForUnfinishedSignIn(named: title),
            isUnfinished: true
        )
    }

    static func row(
        for standing: AgentAccountStanding,
        among standings: [AgentAccountStanding],
        locale: Locale,
        timeZone: TimeZone
    ) -> Row {
        let home = standing.home
        let title = AgentAccountNames.title(of: standing, among: standings)
        let note = note(for: standing)
        return Row(
            id: home.id,
            home: home,
            title: title,
            fields: [
                Field(label: "Email", value: standing.identity.email ?? unknown),
                Field(label: "Plan", value: standing.identity.plan ?? unknown),
                Field(
                    label: "Expires",
                    value: standing.identity.expiresAt.map { expiry($0, locale: locale, timeZone: timeZone) } ?? unknown
                ),
                Field(label: "Session", value: session(of: standing)),
            ],
            note: note.text,
            warns: note.warns,
            removal: home.isDefault
                ? nil
                : AgentAccountRemoval.warning(forAccountNamed: title, folderExists: standing.directoryExists),
            isUnfinished: false
        )
    }

    static func session(of standing: AgentAccountStanding) -> String {
        guard standing.directoryExists else { return standing.home.isDefault ? "Not set up" : "Folder missing" }
        return switch standing.cliReport {
        case .claimsSession: "Signed in"
        case .claimsNoSession: "Not signed in"
        case .unanswered: "Not confirmed"
        }
    }

    private static func note(for standing: AgentAccountStanding) -> (text: String?, warns: Bool) {
        let home = standing.home
        if home.isDefault {
            return ("Used wherever a project has not chosen another account.", false)
        }
        var sentences: [String] = []
        if !standing.directoryExists {
            sentences.append("This account's folder is no longer on this Mac.")
        }
        if let doubt = standing.isolationDoubt {
            sentences.append("Unified Dev does not guarantee this account stays separate for \(home.provider.label). \(doubt)")
        }
        return (sentences.isEmpty ? nil : sentences.joined(separator: " "), !sentences.isEmpty)
    }

    private static func expiry(_ date: Date, locale: Locale, timeZone: TimeZone) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale, timeZone: timeZone))
    }
}
