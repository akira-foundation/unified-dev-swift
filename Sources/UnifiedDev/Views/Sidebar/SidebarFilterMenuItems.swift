import SwiftUI
import Core

struct SidebarFilterMenuItems: View {
    @Binding var filter: SidebarFilter
    @Binding var showsHiddenProjects: Bool
    var hiddenCount: Int

    var body: some View {
        Picker("Workspaces", selection: $filter) {
            ForEach(SidebarFilter.allCases, id: \.self) { option in
                Label(option.rawValue, systemImage: option.icon).tag(option)
            }
        }
        .pickerStyle(.inline)

        Section("Projects") {
            Toggle(
                ProjectVisibility.toggleTitle(hiddenCount: hiddenCount),
                isOn: $showsHiddenProjects
            )
        }
    }
}
