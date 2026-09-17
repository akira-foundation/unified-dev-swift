import Foundation

enum BottomPanelDefaults {
    private static let keys = ["inspector.panelHeight"]

    static func forget() {
        let defaults = UserDefaults.standard
        for key in keys where defaults.object(forKey: key) != nil {
            defaults.removeObject(forKey: key)
        }
    }
}
