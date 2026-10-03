import SwiftUI
import Core

struct SidebarFilterMenuItems: View {
    @Binding var filter: SidebarFilter
    @Binding var showsHiddenProjects: Bool
    var hiddenCount: Int
    @Binding var grouping: String

    var body: some View {
        Picker("Group by", selection: $grouping) {
            ForEach(SidebarGrouping.allCases, id: \.rawValue) { option in
                Label(option.title, systemImage: option.icon).tag(option.rawValue)
            }
        }
        .pickerStyle(.inline)

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
