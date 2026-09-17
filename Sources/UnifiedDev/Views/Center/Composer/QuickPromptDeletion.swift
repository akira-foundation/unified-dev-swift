import Foundation
import Core

extension QuickPromptDeletion {
    static func confirmation(for prompt: QuickPrompt) -> Confirmation {
        Confirmation(
            title: title(for: prompt.resolvedName),
            message: message,
            confirmLabel: confirmLabel,
            cancelLabel: cancelLabel,
            layout: .compact
        )
    }
}
