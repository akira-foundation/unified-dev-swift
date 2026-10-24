import AppKit
import Foundation
import Core

@MainActor
extension Snapshot {
    static var requestedStage: CaptureStage {
        let asked = CommandLine.arguments.contains { $0 == "--stage" || $0.hasPrefix("--stage=") }
        switch CaptureStage.reading(ProbeHarness.value(for: "--stage"), asked: asked) {
        case .stage(let stage):
            return stage
        case .refused(let why):
            FileHandle.standardError.write(Data((why + "\n").utf8))
            exit(1)
        }
    }

    static func refuseOutsideAPreview(_ stage: CaptureStage) {
        guard let why = stage.refusal(inAPreview: (try? PreviewLaunch.root()) != nil) else {
            return
        }
        FileHandle.standardError.write(Data((why + "\n").utf8))
        exit(1)
    }

    static func stage(_ stage: CaptureStage) async {
        defer { quietTheGitHubNotice() }
        guard stage.isArrangedInTheWindow else { return }
        if stage.arrangesTheWorkspace { discardLeftoverDrafts() }
        switch stage {
        case .window, .spend:
            return
        case .review:
            await stageReview()
        case .terminal:
            await stageTerminal()
        case .browser:
            await stageBrowser()
        case .agentChoice:
            CapturePicker.post(.agentSettings)
            try? await Task.sleep(for: .seconds(2))
        case .createWorkspace:
            AppModel.probeInstance?.openDraft(prompt: landingDraft, asksForStartingPoint: true)
            try? await Task.sleep(for: .seconds(4))
        }
    }

    private static let landingDraft = """
        Give the fog bell a configurable interval, defaulting to the thirty seconds it rings at \
        today, and say in the keeping notes where the setting lives.
        """

    private static func stagedModel() -> WorkspaceModel {
        guard let model = AppModel.probeInstance?.selectedModel else {
            FileHandle.standardError.write(Data("no workspace open to stage\n".utf8))
            exit(1)
        }
        CenterTabStore.shared.load(workspaceID: model.workspace.id)
        return model
    }

    private static func stageReview() async {
        let model = stagedModel()
        UserDefaults.standard.set(true, forKey: DiffLayoutSetting.storageKey)
        for _ in 0..<40 where model.changedFiles.isEmpty {
            try? await Task.sleep(for: .milliseconds(250))
        }
        FileReview.openAll(in: model)
        try? await Task.sleep(for: .seconds(3))
    }

    private static func stageTerminal() async {
        let model = stagedModel()
        let tab = CenterTabStore.shared.add(kind: .terminal, workspaceID: model.workspace.id)
        WorkspaceTabsStore.shared.select(.tool(tab.id), in: model)
        NotificationCenter.default.post(name: .unifieddevToggleSidebar, object: nil)
        try? await Task.sleep(for: .seconds(1))
        var sent = false
        for _ in 0..<40 where !sent {
            sent = TerminalSessionStore.shared.write(
                "git status --short --branch", submit: true, paneID: tab.id
            )
            if !sent { try? await Task.sleep(for: .milliseconds(250)) }
        }
        try? await Task.sleep(for: .seconds(2))
    }

    private static func stageBrowser() async {
        let model = stagedModel()
        _ = await AppModel.probeInstance?.splitPaneForBridge(
            PaneOrder(kind: .browser, url: landingBrowserAddress),
            axis: .horizontal,
            anchor: .activePane,
            in: model.workspace.id
        )
        try? await Task.sleep(for: .seconds(6))
    }

    private static let landingBrowserAddress = "https://example.com/"

    private static func discardLeftoverDrafts() {
        guard let app = AppModel.probeInstance else { return }
        for repo in app.repos where app.showsDraft(in: repo.id) {
            app.discardDraft(repo.id)
        }
    }

    private static func quietTheGitHubNotice() {
        for workspace in AppModel.probeInstance?.workspaces ?? [] {
            WorkspacePullRequests.shared.dismissFailure(for: workspace.id)
        }
    }
}
