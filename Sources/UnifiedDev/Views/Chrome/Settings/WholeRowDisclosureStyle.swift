import SwiftUI

struct WholeRowDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        DisclosureGroup(isExpanded: configuration.$isExpanded) {
            configuration.content
        } label: {
            configuration.label
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(Motion.pane) { configuration.isExpanded.toggle() }
                }
        }
        .disclosureGroupStyle(.automatic)
    }
}

extension DisclosureGroupStyle where Self == WholeRowDisclosureStyle {
    static var wholeRow: WholeRowDisclosureStyle { WholeRowDisclosureStyle() }
}
