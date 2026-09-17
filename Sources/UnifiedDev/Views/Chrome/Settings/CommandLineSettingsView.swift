import Core
import SwiftUI

struct CommandLineSettingsView: View {
    @Environment(AppModel.self) private var app

    @State private var attachment: BridgeAttachment?
    @State private var isRegenerating = false

    var body: some View {
        Form {
            if let attachment {
                connectSection(attachment)
                regenerateSection
            } else {
                unavailableSection
            }
        }
        .settingsForm()
        .task { attachment = app.bridge?.ownerAttachment() }
    }

    private func connectSection(_ attachment: BridgeAttachment) -> some View {
        Section {
            CommandLineInstruction(supportsMultipleClients: true)

            commandOffer(
                title: "Claude Code",
                command: BridgeRegistration.ownerAddCommand(attachment)
            )
            commandOffer(
                title: "Codex",
                command: BridgeRegistration.ownerCodexAddCommand(attachment)
            )
            commandOffer(
                title: "Grok",
                command: BridgeRegistration.ownerGrokAddCommand(attachment)
            )
        } header: {
            Text("Use Unified Dev from your own terminal")
        } footer: {
            CommandLineWarning()
                .padding(.top, Metrics.spacingSmall)
        }
    }

    private func commandOffer(title: String, command: String) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacingTight) {
            Text(title)
                .font(Typo.bodyEmphasis)

            CommandLineOffer(command: command)
                .id(command)
        }
    }

    private var regenerateSection: some View {
        Section {
            SettingsRow("Access token") {
                HStack(spacing: Metrics.gutter) {
                    Text("Disconnects registered clients. Run the new commands to reconnect.")
                        .settingsFootnote()

                    Spacer()

                    Button("Regenerate Token", role: .destructive) { regenerate() }
                        .disabled(isRegenerating)
                }
            }
        } header: {
            Text("Connection security")
        } footer: {
            Text(
                "Regenerate if your token was exposed. The old token stops working immediately."
            )
            .settingsFootnote()
        }
    }

    private var unavailableSection: some View {
        Section("Use Unified Dev from your own terminal") {
            Text(
                "The bridge this would connect through is not running, so this copy of Unified Dev "
                    + "cannot be reached from an outside client. Reinstalling Unified Dev is the fix."
            )
            .settingsFootnote()
        }
    }

    private func regenerate() {
        guard let bridge = app.bridge else { return }
        isRegenerating = true
        defer { isRegenerating = false }
        do {
            try bridge.regenerateOwnerToken()
            attachment = bridge.ownerAttachment()
        } catch {
            app.alert = AppAlert(
                title: "Could not regenerate the token",
                message: error.readableMessage
            )
        }
    }
}
