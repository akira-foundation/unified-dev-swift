import SwiftUI
import Core

struct ProfileAccountSignInSection: View {
    let profile: Profile

    @Environment(AppModel.self) private var app

    @State private var flow: AgentAccountsFlow
    @State private var executables: [AgentKind: String] = [:]

    private var providers: [AgentKind] {
        ProfileAccountSignIn.providers(
            executables: Set(executables.keys), codexStorageMode: app.agentAccounts.codexStorageMode
        )
    }

    init(profile: Profile) {
        self.profile = profile
        _flow = State(initialValue: AgentAccountsFlow(profile: profile.id))
    }

    var body: some View {
        ProfileAccountSignInButtons(
            providers: providers,
            profileName: profile.name,
            isSigningIn: app.agentAccounts.activity == .confirmingSignIn
        ) { provider in
            flow.namingProvider = provider
            flow.isNamingAccount = true
        }
        .task { executables = await Self.installedExecutables(store: app.store) }
        .agentAccountsFlow(
            flow, app: app, provider: flow.namingProvider ?? .claudeCode, executables: executables,
            onSignInClosed: {}
        )
    }

    private static func installedExecutables(store: Store?) async -> [AgentKind: String] {
        let statuses: [AgentStatus]
        if let seeded = PreviewScenario.AgentSettings.seeded() {
            statuses = seeded.statuses
        } else {
            let overrides = await AgentCatalog.executablePathOverrides(in: store)
            statuses = await AgentCatalog(overrides: overrides).statuses()
        }
        return Dictionary(statuses.map { ($0.kind, $0.executablePath) }, uniquingKeysWith: { _, latest in latest })
            .compactMapValues { $0 }
    }
}

struct ProfileAccountSignInButtons: View {
    let providers: [AgentKind]
    let profileName: String
    var isSigningIn = false
    let onSignIn: (AgentKind) -> Void

    var body: some View {
        Section {
            ForEach(providers) { provider in
                Button(ProfileAccountSignIn.title(for: provider)) { onSignIn(provider) }
                    .disabled(isSigningIn)
            }
        } footer: {
            Text(ProfileAccountSignIn.footer(profileName: profileName))
                .settingsFootnote()
        }
    }
}
