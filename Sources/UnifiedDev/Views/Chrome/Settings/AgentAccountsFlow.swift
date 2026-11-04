import SwiftUI
import Core

@MainActor
@Observable
final class AgentAccountsFlow {
    var loginRequest: AgentSignInSheet.Request?
    var isNamingAccount = false
    var accountLabel = ""
    var removing: AgentAccountPanel.Row?

    @ObservationIgnored private var creation: AgentAccountsModel.Creation?
    @ObservationIgnored private var lastExit: TerminalExit?

    var isCreating: Bool { creation != nil }

    func noteLoginExit(_ exit: TerminalExit?) {
        lastExit = exit
    }

    func beginAccount(provider: AgentKind, executable: String?, app: AppModel) {
        let label = accountLabel
        accountLabel = ""
        guard let executable else { return }
        Task {
            guard let made = await app.agentAccounts.beginCreation(
                provider: provider, label: label, store: app.store
            ) else { return }
            creation = made
            lastExit = nil
            loginRequest = AgentSignInSheet.Request(
                account: made.plan.home, label: made.plan.label, executable: executable
            )
        }
    }

    func loginDismissed(executables: [AgentKind: String], app: AppModel) -> Bool {
        guard let finished = creation else { return false }
        let exit = lastExit
        creation = nil
        lastExit = nil
        Task {
            await app.agentAccounts.finishCreation(
                finished, exit: exit, executables: executables, store: app.store
            )
        }
        return true
    }

    func remove(_ row: AgentAccountPanel.Row, app: AppModel) {
        Task {
            await app.agentAccounts.remove(row, store: app.store)
            await app.reload()
        }
    }
}

private struct AgentAccountsFlowModifier: ViewModifier {
    @Bindable var flow: AgentAccountsFlow
    let app: AppModel
    let provider: AgentKind
    let executables: [AgentKind: String]
    let onSignInClosed: () -> Void

    func body(content: Content) -> some View {
        content
            .task(id: executables) {
                await app.agentAccounts.reload(store: app.store)
                guard !executables.isEmpty else { return }
                await app.agentAccounts.askIfDue(
                    after: QuotaPollSchedule.onDemandFloor, executables: executables, store: app.store
                )
            }
            .sheet(item: $flow.loginRequest, onDismiss: {
                if !flow.loginDismissed(executables: executables, app: app) { onSignInClosed() }
            }) { request in
                AgentSignInSheet(request: request) { exit in
                    flow.noteLoginExit(exit)
                    if !flow.isCreating, exit != nil { onSignInClosed() }
                }
            }
            .alert("Add a \(provider.label) account", isPresented: $flow.isNamingAccount) {
                TextField("Name", text: $flow.accountLabel)
                Button("Continue") {
                    flow.beginAccount(provider: provider, executable: executables[provider], app: app)
                }
                .disabled(AgentAccountCreation.cleanLabel(flow.accountLabel) == nil)
                Button("Cancel", role: .cancel) { flow.accountLabel = "" }
            } message: {
                Text("Choose a name for the account. Once you have signed in, Unified Dev shows the account by its email.")
            }
            .alert(
                flow.removing?.removal?.title ?? "",
                isPresented: Binding(get: { flow.removing != nil }, set: { if !$0 { flow.removing = nil } }),
                presenting: flow.removing
            ) { row in
                Button(row.removal?.actionTitle ?? "Remove", role: .destructive) { flow.remove(row, app: app) }
                Button("Cancel", role: .cancel) {}
            } message: { row in
                Text(row.removal?.message ?? "")
            }
    }
}

extension View {
    func agentAccountsFlow(
        _ flow: AgentAccountsFlow,
        app: AppModel,
        provider: AgentKind,
        executables: [AgentKind: String],
        onSignInClosed: @escaping () -> Void
    ) -> some View {
        modifier(AgentAccountsFlowModifier(
            flow: flow, app: app, provider: provider, executables: executables, onSignInClosed: onSignInClosed
        ))
    }
}
