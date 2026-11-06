import Foundation

public enum ProfileAccountSignIn {
    public static func providers(
        executables: Set<AgentKind>, codexStorageMode: CodexAuthStorageMode
    ) -> [AgentKind] {
        AgentKind.allCases.filter { provider in
            executables.contains(provider)
                && AgentAccountOffer.make(for: provider, codexStorageMode: codexStorageMode).isAvailable
        }
    }

    public static func title(for provider: AgentKind) -> String {
        "Sign in with a \(provider.label) account\u{2026}"
    }

    public static func footer(profileName: String) -> String {
        "An account signed in here belongs to \(profileName), whichever profile the window is showing."
    }

    public static func keepsSheetOpen(after saved: ProfileDraft) -> Bool {
        saved.accounts == .own && saved.storedAccounts != .own
    }

    public static func owner(editing profile: ProfileID?, active: ProfileID) -> ProfileID {
        profile ?? active
    }
}
