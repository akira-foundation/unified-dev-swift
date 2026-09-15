import SwiftUI

/// Which part of a project's settings is showing.
///
/// A type of its own rather than an enum nested inside the view, because three things outside
/// that view now answer to it: the toolbar that draws the choice, the window that has to say
/// which item is selected, and a capture run that names the pane it wants photographed.
///
/// Named `Pane` rather than `Tab` because `Tab` is SwiftUI's own type, and because these are not
/// tabs: they are the rows of a source list, the way the app's own settings window lists its own.
enum RepoSettingsPane: String, CaseIterable, Hashable {
    case project
    case workspaces
    case scripts
    case instructions

    /// The word under the icon.
    var title: String {
        switch self {
        case .project: "Project"
        case .workspaces: "Workspaces"
        case .scripts: "Scripts"
        case .instructions: "Instructions"
        }
    }

    /// The glyph on the row's tile. Every pane has one, which is why this is not optional.
    var systemImage: String {
        switch self {
        case .project: "folder"
        case .workspaces: "square.stack.3d.up"
        case .scripts: "terminal"
        case .instructions: "text.book.closed"
        }
    }

    /// The colour of the tile the source list draws the glyph on, which is the pattern the app's
    /// own settings window uses and the pattern System Settings uses before it.
    var tint: Color {
        switch self {
        case .project: .gray
        case .workspaces: Palette.accentFill
        case .scripts: Color(nsColor: .darkGray)
        case .instructions: .teal
        }
    }

    /// Which pane a window opens on, from `UD_PANE=workspaces|scripts|instructions`.
    ///
    /// A capture run can open this window through `--repo-settings` and cannot press anything in
    /// it, so without this the other two panes go in unverified. Nil for anything else, including
    /// nothing at all, and the window falls back to Project.
    static var requested: RepoSettingsPane? {
        guard let named = ProcessInfo.processInfo.environment["UD_PANE"] else { return nil }
        return RepoSettingsPane(rawValue: named)
    }
}
