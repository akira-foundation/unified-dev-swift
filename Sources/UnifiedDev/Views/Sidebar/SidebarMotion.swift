import SwiftUI
import Core

struct SidebarMotion {
    var hasSettled: Bool
    var reduceMotion: Bool
    var showsHiddenProjects: Bool

    var fold: Animation? {
        guard !reduceMotion, hasSettled else { return nil }
        return Motion.pane
    }

    var visibility: Animation? {
        guard hasSettled,
              let seconds = ProjectVisibilityMotion
                  .hideGesture(showingHidden: showsHiddenProjects, reduceMotion: reduceMotion)
                  .seconds
        else { return nil }
        return .easeOut(duration: seconds)
    }

    var workspace: Animation? {
        guard hasSettled, !reduceMotion else { return nil }
        return .easeOut(duration: ProjectVisibilityMotion.seconds)
    }

    var subagent: Animation? {
        guard hasSettled,
              let seconds = ProjectVisibilityMotion.subagentRemoval(reduceMotion: reduceMotion).seconds
        else { return nil }
        return .easeOut(duration: seconds)
    }
}
