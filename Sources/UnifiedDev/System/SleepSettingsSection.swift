import SwiftUI
import Core

struct SleepSettingsSection: View {
    @AppStorage(SleepPrevention.settingKey) private var preventsSleep = SleepPrevention.isOnByDefault

    var body: some View {
        Section {
            Toggle(isOn: $preventsSleep) {
                Text(SleepPrevention.settingTitle)
                Text(SleepPrevention.settingDetail)
            }
        } header: {
            Text("While agents work")
        } footer: {
            Text(SleepPrevention.caveat)
                .settingsFootnote()
        }
    }
}
