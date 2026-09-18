import SwiftUI
import Core

struct ComposerPlace {
    var mentionRoot: String
    var attachmentRoot: String
    var attachmentKey: String
    var placeholder: String
    var project: String?
    var projectQuickPrompts: [ProjectQuickPrompt] = []
    var onOpenQuickPrompts: (@MainActor () -> Void)?
}

struct ComposerSend {
    var intent: ComposerIntent = .send
    var canSend: Bool
    var perform: @MainActor () -> Void
    var onQuickPrompt: @MainActor (QuickPromptPanelRow, @MainActor (QuickPromptPanelRow) -> Void) -> Void
    var usesCLIChat: Binding<Bool>?
    var supportsCLIChat: Bool = true
}

struct ComposerConversation {
    var reviewComments: [ReviewComment] = []
    var onRemoveReviewComment: @MainActor (ReviewCommentID) -> Void = { _ in }
    var onOpenReviewComment: @MainActor (ReviewComment) -> Void = { _ in }
    var onOpenCommand: (@MainActor (String) -> Void)?
    var context: ContextWindowUsage?
    var isRunning = false
    var queues = false
    var onStop: @MainActor () -> Void = {}
    var onSideConversation: (@MainActor () -> Void)?
}

struct ComposerSurface: View {
    @Binding var text: String
    @Binding var caret: Int
    @Binding var isFocused: Bool
    var place: ComposerPlace
    var editorHeight: CGFloat
    var onContentHeightChange: @MainActor (CGFloat) -> Void
    var controls: ComposerControls
    var onControlsChange: @MainActor (ComposerControls) -> Void
    var send: ComposerSend
    var conversation = ComposerConversation()
    var onOpenAttachment: @MainActor (PromptAttachment) -> Void
    var onEscape: @MainActor () -> Void

    var body: some View {
        ComposerPrompt(
            text: $text,
            caret: $caret,
            isFocused: $isFocused,
            mentionRoot: place.mentionRoot,
            attachmentRoot: place.attachmentRoot,
            attachmentKey: place.attachmentKey,
            reviewComments: conversation.reviewComments,
            onRemoveReviewComment: conversation.onRemoveReviewComment,
            onOpenReviewComment: conversation.onOpenReviewComment,
            placeholder: place.placeholder,
            editorHeight: editorHeight,
            onContentHeightChange: onContentHeightChange,
            onKey: handle(key:),
            onOpenAttachment: onOpenAttachment,
            onOpenCommand: conversation.onOpenCommand,
            isFloating: true,
            isBusy: conversation.isRunning
        ) { actions in
            ComposerFooterView(
                controls: controls,
                onChange: onControlsChange,
                context: conversation.context,
                isRunning: conversation.isRunning,
                queues: conversation.queues,
                canSend: send.canSend,
                intent: send.intent,
                project: place.project,
                onAttach: actions.attach,
                onQuickPrompt: { send.onQuickPrompt($0, actions.insert) },
                projectQuickPrompts: place.projectQuickPrompts,
                onOpenQuickPrompts: place.onOpenQuickPrompts,
                onSend: send.perform,
                onStop: conversation.onStop,
                onSideConversation: conversation.onSideConversation,
                usesCLIChat: send.usesCLIChat,
                supportsCLIChat: send.supportsCLIChat
            )
        }
    }

    private func handle(key: ComposerKey) -> Bool {
        switch key {
        case .returnKey, .commandReturn:
            send.perform()
            return true
        case .escape:
            onEscape()
            return true
        case .up, .down, .tab:
            return false
        }
    }
}
