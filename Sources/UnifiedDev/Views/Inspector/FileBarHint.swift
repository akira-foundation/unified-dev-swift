import SwiftUI
import Core

extension View {
    func fileBarHint(_ control: FileBarControl, into hint: Binding<String?>) -> some View {
        onHover { isInside in
            if isInside {
                hint.wrappedValue = control.hint
            } else if hint.wrappedValue == control.hint {
                hint.wrappedValue = nil
            }
        }
        .help(control.hint)
    }
}

struct FileBarHintLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Typo.caption)
            .foregroundStyle(Palette.textSecondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .accessibilityHidden(true)
    }
}
