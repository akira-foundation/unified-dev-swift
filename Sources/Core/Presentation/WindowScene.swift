public enum WindowScene {
    public static func names(_ identifier: String?, _ sceneID: String) -> Bool {
        guard let identifier else { return false }
        return identifier == sceneID || identifier.hasPrefix(sceneID + "-")
    }
}
