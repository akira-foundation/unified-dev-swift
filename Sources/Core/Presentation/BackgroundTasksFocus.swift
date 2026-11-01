import Foundation

public struct BackgroundTasksFocus: Sendable, Hashable {
    private var chosen: SessionID?
    private var chosenWhileActive: SessionID?

    public init() {}

    public mutating func choose(_ session: SessionID, active: SessionID?) {
        chosen = session
        chosenWhileActive = active
    }

    public mutating func activeChatChanged() {
        chosen = nil
        chosenWhileActive = nil
    }

    public func session(active: SessionID?) -> SessionID? {
        guard let chosen, chosenWhileActive == active else { return active }
        return chosen
    }
}
