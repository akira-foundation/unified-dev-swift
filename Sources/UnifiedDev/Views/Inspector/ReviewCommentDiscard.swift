import Core

extension ReviewCommentDiscard {
    var confirmation: Confirmation {
        Confirmation(
            title: title,
            message: message,
            confirmLabel: confirmLabel,
            cancelLabel: cancelLabel
        )
    }
}
