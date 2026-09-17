import Foundation

public enum ProjectVisibility {
    public static let showsHiddenKey = "sidebar.showsHiddenProjects"

    public static func listed(_ repos: [Repo], showingHidden: Bool) -> [Repo] {
        showingHidden ? repos : repos.filter { !$0.hidden }
    }

    public static func hiddenCount(_ repos: [Repo]) -> Int {
        repos.count { $0.hidden }
    }

    public static func toggleTitle(hiddenCount: Int) -> String {
        switch hiddenCount {
        case 0: "Show hidden projects"
        case 1: "Show 1 hidden project"
        default: "Show \(hiddenCount) hidden projects"
        }
    }

    public static func comesBack(_ project: Repo?) -> Bool {
        project?.hidden == true
    }

    public static func remainingSentence(visible: Int) -> String {
        switch visible {
        case 0:
            return "No projects are left showing in Unified Dev's sidebar. They are all still there: "
                + "turn on Show hidden projects in the sidebar's filter menu, or call "
                + "project_unhide, to bring one back."
        case 1:
            return "1 project is still showing in Unified Dev's sidebar."
        default:
            return "\(visible) projects are still showing in Unified Dev's sidebar."
        }
    }
}
