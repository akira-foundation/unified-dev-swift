import SwiftUI
import Core

struct BrowserMenuCommands: View {
    var session: BrowserSession?

    var body: some View {
        let state = session?.paneState
        ForEach(BrowserCommand.menuRows, id: \.self) { command in
            MenuCommand(command.menuAction, alternate: state?.usesAlternateTitle(command) == true) {
                session?.run(command)
            }
            .disabled(state?.isEnabled(command) != true)
        }
    }
}
