import SwiftUI
import Core

struct UpdateSettingsSection: View {
    private let updater = SoftwareUpdater.shared

    var body: some View {
        Section(SoftwareUpdate.sectionTitle) {
            if let explanation = SoftwareUpdate.unavailableExplanation(updater.availability) {
                Text(explanation)
                    .settingsFootnote()
            } else {
                Toggle(isOn: checksAutomatically) {
                    Text(SoftwareUpdate.settingTitle)
                    Text(SoftwareUpdate.settingDetail)
                }

                Button("Check for Updates Now") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
            }
        }
    }

    private var checksAutomatically: Binding<Bool> {
        Binding(
            get: { updater.checksAutomatically },
            set: { updater.setChecksAutomatically($0) }
        )
    }
}
