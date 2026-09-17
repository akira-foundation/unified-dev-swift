import Foundation

public enum ReviewComposer {
    public static func isDrawn(destination: SessionID?, panes: [PaneContent]) -> Bool {
        guard let destination else { return false }
        return !panes.contains(.chat(destination))
    }
}
