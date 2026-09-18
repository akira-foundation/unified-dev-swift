import Foundation
import Core

extension RunScriptLauncher {
    func menuItem(for script: RunScript, in model: WorkspaceModel) -> RunScriptMenuItem {
        RunScriptMenuItem.make(
            script: script,
            isRunning: runningScripts(in: model).contains(script.id),
            missingFile: missingFile(of: script, in: model)
        )
    }

    private func runningScripts(in model: WorkspaceModel) -> Set<String> {
        Set(CenterTabStore.shared.tabs(for: model.workspace.id).compactMap { tab in
            isRunning(tab) ? tab.runScriptID : nil
        })
    }

    private func missingFile(of script: RunScript, in model: WorkspaceModel) -> String? {
        guard let file = model.settings.scriptFiles[.run(script.id)], file.isMissing else { return nil }
        return file.path
    }
}
