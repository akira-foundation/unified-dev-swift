public enum EditorEcho {
    public static func wouldDiscardTyping(published: String?, shown: String, incoming: String) -> Bool {
        guard let published else { return false }
        return shown == published && incoming != published
    }
}
