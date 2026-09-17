import SwiftUI
import Core

struct InstallPingSettingsSection: View {
    @AppStorage(InstallPing.settingKey) private var sendsInstallPing = InstallPing.isOnByDefault

    var body: some View {
        Section {
            Toggle(isOn: $sendsInstallPing) {
                Text(InstallPing.settingTitle)
                Text(InstallPing.settingDetail)
            }
        } header: {
            Text("Installation reporting")
        } footer: {
            Text(InstallPing.settingFooter)
                .settingsFootnote()
        }
    }
}
