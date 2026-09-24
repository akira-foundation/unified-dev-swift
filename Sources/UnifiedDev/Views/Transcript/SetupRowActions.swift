import SwiftUI

struct SetupRowActions: View {
    let event: WorkspaceEvent
    let model: WorkspaceModel?
    let canExpand: Bool
    let hasMoreToShow: Bool
    @Binding var isExpanded: Bool

    var showsButtons: Bool { showsRunSetupAgain || showsIgnoreFailure || showsStopSetup }

    var isEmpty: Bool { !showsExpandLink && !showsButtons }

    var body: some View {
        HStack(spacing: Metrics.gutter) {
            if showsExpandLink {
                Button(isExpanded ? "Show less" : "Show more of the log") { isExpanded.toggle() }
                    .linkButton()
                    .font(Typo.caption)
                    .help(isExpanded ? "Folds the log back to its last lines" : "Unfolds the log in this row")
                    .accessibilityHidden(true)
            }

            if showsRunSetupAgain, let model {
                Button("Run setup again") { SetupRunAlert.shared.ask(model) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(Typo.caption)
                    .help("Asks, then runs this repository's setup script in this workspace again")
            }

            if showsIgnoreFailure, let model {
                Button("Ignore") { model.ignoreSetupFailure() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(Typo.caption)
                    .help("Keeps the log, and stops showing this workspace as failed")
            }

            if showsStopSetup, let model {
                Button("Stop setup") { model.stopSetup() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(Typo.caption)
                    .help("Stops the setup script. Anything waiting for it goes to the agent")
            }
        }
    }

    private var showsExpandLink: Bool {
        event.kind == .setup && canExpand && (isExpanded || hasMoreToShow)
    }

    private var showsRunSetupAgain: Bool {
        event.kind == .setup && [.failed, .ignored].contains(event.outcome) && model?.canRunSetup == true
    }

    private var showsIgnoreFailure: Bool {
        event.kind == .setup && event.outcome == .failed && model?.canIgnoreSetupFailure == true
    }

    private var showsStopSetup: Bool {
        event.kind == .setup && event.isRunning && model?.isRunningSetup == true
    }
}
