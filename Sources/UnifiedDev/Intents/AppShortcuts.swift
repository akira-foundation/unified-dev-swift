import AppIntents

struct AppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ListWorkspacesIntent(),
            phrases: [
                "List \(.applicationName) workspaces",
                "What is running in \(.applicationName)",
                "\(.applicationName) workspaces",
            ],
            shortTitle: "List Workspaces",
            systemImageName: "square.stack.3d.up"
        )
    }
}
