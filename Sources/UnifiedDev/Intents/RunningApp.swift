import AppKit
import Foundation
import Core

@MainActor
enum RunningApp {
    private static weak var model: AppModel?

    static func attach(_ model: AppModel) {
        Self.model = model
    }

    static func startWorkspace(in repo: Repo, prompt: String) async throws -> Workspace {
        guard let model else { throw AppNotReady.stillStartingUp }
        MainWindow.raise()
        return try await model.startWorkspace(in: repo, prompt: prompt)
    }

    static func waitUntilReady(timeout: Duration = .seconds(20)) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if hasWindow { return true }
            try? await Task.sleep(for: .milliseconds(150))
        }
        return hasWindow
    }

    static func open(_ url: URL) {
        MainWindow.raise()
        NotificationCenter.default.post(name: .unifieddevHandleURL, object: url)
    }

    static func select(workspaceID: WorkspaceID) {
        MainWindow.raise()
        OpenWorkspaceNotification.post(workspaceID)
    }

    private static var hasWindow: Bool {
        NSApp.windows.contains { $0.isVisible && $0.styleMask.contains(.titled) && $0.canBecomeMain }
    }
}
