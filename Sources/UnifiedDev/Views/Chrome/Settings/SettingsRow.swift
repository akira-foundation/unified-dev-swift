import AppKit
import SwiftUI

struct SettingsRow<Label: View, Content: View>: View {
    @ViewBuilder var content: () -> Content
    @ViewBuilder var label: () -> Label

    var body: some View {
        LabeledContent(content: content, label: label)
            .labeledContentStyle(SettingsRowStyle())
    }
}

extension SettingsRow where Label == Text {
    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.init(content: content, label: { Text(title) })
    }
}

extension SettingsRow where Label == Text, Content == Text {
    init(_ title: String, value: String) {
        self.init(content: { Text(value) }, label: { Text(title) })
    }
}

extension View {
    func settingsRowBaseline() -> some View {
        alignmentGuide(.firstTextBaseline) { dimensions in
            dimensions[VerticalAlignment.center]
                + NSFont.preferredFont(forTextStyle: .body).capHeight / 2
        }
    }
}

private struct SettingsRowStyle: LabeledContentStyle {
    @Environment(\.settingsLabelColumn) private var column

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.gutter) {
            configuration.label
                .fixedSize(horizontal: true, vertical: false)
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: SettingsLabelWidth.self, value: proxy.size.width)
                })
                .frame(width: column > 0 ? column : nil, alignment: .leading)

            configuration.content
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
    }
}
