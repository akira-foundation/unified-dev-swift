import AppIntents

struct OpenWorkspaceIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Workspace"

    static let description = IntentDescription(
        "Brings Unified Dev to the front and selects a workspace.",
        categoryName: "Workspaces"
    )

    static let openAppWhenRun = true

    @Parameter(title: "Workspace")
    var workspace: WorkspaceEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$workspace) in Unified Dev")
    }

    func perform() async throws -> some IntentResult {
        guard await RunningApp.waitUntilReady() else { throw IntentFailure.appNeverAppeared }
        await RunningApp.select(workspaceID: workspace.id)
        return .result()
    }
}
