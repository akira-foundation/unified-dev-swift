import SwiftUI
import Core

struct CrashReportingSettingsSection: View {
    @AppStorage(CrashReporting.settingKey) private var sendsCrashReports = CrashReporting.isOnByDefault

    var body: some View {
        Section {
            Toggle(isOn: $sendsCrashReports) {
                Text("Send crash reports")
                Text("Help us fix crashes by sending technical details when Unified Dev next opens.")
            }
        } header: {
            Text("Crash reporting")
        } footer: {
            Text("Includes your Mac model, memory, Unified Dev and macOS versions, and crash stack traces. Changes take effect after restarting Unified Dev.")
                .settingsFootnote()
        }
    }
}
