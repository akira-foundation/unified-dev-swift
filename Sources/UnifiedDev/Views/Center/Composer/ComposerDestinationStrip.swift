import SwiftUI
import Core

struct ComposerDestination: Identifiable, Hashable {
    var id: SessionID
    var title: String

    var name: String { title.isEmpty ? PaneNaming.untitledChat : title }
}

struct ComposerDestinationStrip: View {
    var label: String
    var destinations: [ComposerDestination] = []
    var selected: SessionID?
    var onSelect: ((SessionID) -> Void)?

    private var isChoosable: Bool {
        onSelect != nil && ReviewDestination.isChoosable(sessions: destinations.map(\.id))
    }

    var body: some View {
        Group {
            if isChoosable, let onSelect {
                Menu {
                    Picker("Send to", selection: Binding(
                        get: { selected },
                        set: { if let id = $0 { onSelect(id) } }
                    )) {
                        ForEach(destinations) { destination in
                            Text(destination.name).tag(SessionID?.some(destination.id))
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } label: {
                    line(showsIndicator: true)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .buttonStyle(.glass)
                .help("Choose the chat this review is sent to")
                .accessibilityLabel(label)
                .accessibilityHint("Choose the chat this review is sent to")
            } else {
                line(showsIndicator: false)
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .frame(maxWidth: .infinity, minHeight: Metrics.rowHeight, alignment: .leading)
    }

    private func line(showsIndicator: Bool) -> some View {
        HStack(spacing: Metrics.spacingSmall) {
            Image(systemName: "bubble.left")
            Text(label)
                .lineLimit(1)
                .truncationMode(.middle)
            if showsIndicator {
                Image(systemName: "chevron.down")
                    .imageScale(.small)
            }
        }
        .font(Typo.caption)
        .foregroundStyle(Palette.textTertiary)
        .contentShape(Rectangle())
    }
}
