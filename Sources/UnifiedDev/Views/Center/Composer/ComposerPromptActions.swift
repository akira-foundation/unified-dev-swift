import Core

@MainActor
struct ComposerPromptActions {
    var attach: @MainActor () -> Void
    var insert: @MainActor (QuickPromptPanelRow) -> Void
}
