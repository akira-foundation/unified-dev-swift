import SwiftUI
import Core

struct ProfileGitHubSection: View {
    let profile: Profile

    @Environment(AppModel.self) private var app

    @State private var source: ProfileGitHubSource = .inherits
    @State private var user: String?
    @State private var isChecking = true
    @State private var signIn: GitHubSignIn.Request?
    @State private var refresh = 0

    private var login: GitHubLogin {
        app.store?.gitHubLogin(for: profile.id) ?? .thisMac
    }

    var body: some View {
        ProfileGitHubRows(
            source: binding,
            choosesSource: !profile.isInitial,
            user: user,
            isChecking: isChecking,
            footnote: ProfileGitHubWording.footnote(
                source: source, isInitial: profile.isInitial, profileName: profile.name, user: user
            ),
            canSignIn: source == .own && !profile.isInitial,
            onSignIn: startSignIn
        )
        .task(id: "\(profile.id.rawValue).\(source.rawValue).\(refresh)") {
            source = app.gitHubSource(of: profile.id)
            isChecking = true
            user = await GitHub.signedInUser(login: login)
            isChecking = false
        }
        .sheet(item: $signIn) { pending in
            GitHubSignInSheet(request: pending) { _ in
                signIn = nil
                refresh += 1
            }
        }
    }

    private var binding: Binding<ProfileGitHubSource> {
        Binding(
            get: { source },
            set: { chosen in
                source = chosen
                Task { await app.setGitHubSource(chosen, for: profile.id) }
            }
        )
    }

    private func startSignIn() {
        let login = login
        Task {
            let state = await GitHubAvailability.shared.check(login: login, force: true)
            signIn = GitHubSignIn.Request(
                access: state == .notInstalled ? .notInstalled : .signedOut,
                directory: AgentScratchDirectory.current(),
                login: login
            )
        }
    }
}

struct ProfileGitHubRows: View {
    @Binding var source: ProfileGitHubSource
    var choosesSource: Bool
    var user: String?
    var isChecking: Bool
    var footnote: String
    var canSignIn: Bool
    var onSignIn: () -> Void

    var body: some View {
        Section {
            if choosesSource {
                Picker(ProfileGitHubWording.pickerTitle, selection: $source) {
                    ForEach(ProfileGitHubSource.allCases, id: \.self) { source in
                        Text(ProfileGitHubWording.label(source)).tag(source)
                    }
                }
            }
            LabeledContent(ProfileGitHubWording.accountTitle) {
                if isChecking {
                    Text(ProfileGitHubWording.checking)
                        .foregroundStyle(.secondary)
                } else {
                    Text(user ?? ProfileGitHubWording.notSignedIn)
                        .foregroundStyle(user == nil ? .secondary : .primary)
                }
            }
            if canSignIn {
                Button(ProfileGitHubWording.signInTitle(isSignedIn: user != nil), action: onSignIn)
                    .disabled(isChecking)
            }
        } header: {
            Text(ProfileGitHubWording.sectionTitle)
        } footer: {
            Text(footnote)
                .settingsFootnote()
        }
    }
}
