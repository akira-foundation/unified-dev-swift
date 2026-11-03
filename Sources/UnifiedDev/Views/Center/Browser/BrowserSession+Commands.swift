import AppKit
import Core

struct BrowserActivity: Equatable {
    var isCapturing = false
    var isReviewing = false
    var isSaving = false
    var isEditingComment = false
}

struct BrowserPageActions {
    var capture: @MainActor () -> Void
    var comment: @MainActor () -> Void
}

extension BrowserSession {
    var paneState: BrowserPaneState { state(loadProgress: 0) }

    var toolbar: BrowserToolbar { state(loadProgress: loadProgress).toolbar }

    private func state(loadProgress: Double) -> BrowserPaneState {
        BrowserPaneState(
            toolbar: BrowserToolbar(
                page: page,
                canGoBack: canGoBack,
                canGoForward: canGoForward,
                isLoading: isLoading,
                loadProgress: loadProgress,
                isCapturing: activity.isCapturing
            ),
            viewport: viewport,
            isReviewing: activity.isReviewing,
            isSaving: activity.isSaving,
            isEditingComment: activity.isEditingComment
        )
    }

    func run(_ command: BrowserCommand) {
        let state = paneState
        guard state.isEnabled(command) else { return }
        switch command {
        case .back: goBack()
        case .forward: goForward()
        case .reload:
            if isLoading { webView.stopLoading() } else { reload() }
        case .responsivePreview: viewport.isEnabled.toggle()
        case .fullSize: viewport.isEnabled = false
        case .screenshot: pageActions?.capture()
        case .comment: pageActions?.comment()
        case .openInDefaultBrowser:
            if let url = state.toolbar.externalURL { NSWorkspace.shared.open(url) }
        }
    }
}
