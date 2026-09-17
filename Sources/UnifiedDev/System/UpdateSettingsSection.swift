import SwiftUI
import Core

struct UpdateSettingsSection: View {
    private let updater = SoftwareUpdater.shared

    @AppStorage(SoftwareUpdate.checksAutomaticallyKey)
    private var checksAutomatically = SoftwareUpdate.checksAutomaticallyByDefault

    var body: some View {
        Section(SoftwareUpdate.sectionTitle) {
            switch updater.availability {
            case .localBuild:
                Text(SoftwareUpdate.localBuildExplanation)
                    .settingsFootnote()
            case .available:
                Toggle(isOn: $checksAutomatically) {
                    Text(SoftwareUpdate.settingTitle)
                    Text(SoftwareUpdate.settingDetail)
                }

                Button(buttonTitle) {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
            }
        }
    }

    private var buttonTitle: String {
        switch updater.phase {
        case .idle: "Check for Updates Now"
        case .checking: "Checking\u{2026}"
        case .installing: "Installing\u{2026}"
        }
    }
}
