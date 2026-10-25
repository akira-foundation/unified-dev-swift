import SwiftUI
import Core

struct SpendAccountsList: View {
    let accounts: [SpendAccountLine]

    @State private var opened: Set<String> = []

    var body: some View {
        if accounts.isEmpty {
            Text(SpendBoard.emptyLine).settingsFootnote()
        }
        ForEach(accounts) { account in
            DisclosureGroup(isExpanded: binding(for: account)) {
                ForEach(account.sessions) { session in
                    SpendSessionRow(session: session)
                }
            } label: {
                LabeledContent {
                    Text(SpendLines.cost(account.spend)).monospacedDigit()
                } label: {
                    Label(account.name, systemImage: "circle.fill")
                        .labelStyle(SpendDotLabelStyle(
                            ink: Color(hexString: ProviderAccent.hex(for: account.provider))
                        ))
                    Text(SpendLines.accountCaption(account))
                }
            }
        }
    }

    private func binding(for account: SpendAccountLine) -> Binding<Bool> {
        Binding(
            get: { opened.contains(account.id) },
            set: { isOpen in
                if isOpen { opened.insert(account.id) } else { opened.remove(account.id) }
            }
        )
    }
}
