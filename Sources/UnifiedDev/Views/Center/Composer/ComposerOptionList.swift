import SwiftUI
import Core

struct ComposerOptionList: View {
    var options: [ComposerOption]
    var footnote: String?
    var selection: String
    var heading: String
    var onSelect: @MainActor (String) -> Void
    var onClose: @MainActor () -> Void

    @State private var highlighted: String?
    @State private var contentHeight: CGFloat = 0

    static let width: CGFloat = 380

    private static let listInset: CGFloat = Metrics.spacingWide
    private static let maxListHeight: CGFloat = 460

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headingRow
            Hairline()
            rows

            if let footnote, !footnote.isEmpty {
                Hairline()
                Text(footnote)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Self.listInset + Metrics.spacing)
                    .padding(.vertical, Metrics.spacingWide)
            }
        }
        .frame(width: Self.width)
        .background(MenuKeyHost(onKey: handle(key:)))
        .onAppear {
            highlighted = selection
        }
    }

    private var headingRow: some View {
        Text(heading.uppercased())
            .font(Typo.micro)
            .tracking(Typo.microTracking)
            .foregroundStyle(Palette.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Self.listInset + Metrics.spacing)
            .padding(.vertical, Metrics.spacingWide)
    }

    private var rows: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(options) { option in
                        ComposerOptionRow(
                            option: option,
                            isSelected: option.id == selection,
                            isHighlighted: option.id == highlighted,
                            onPick: { pick(option.id) },
                            onHover: { highlighted = option.id }
                        )
                        .id(option.id)
                    }
                }
                .padding(.horizontal, Self.listInset)
                .padding(.vertical, Metrics.spacingSmall)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            .frame(height: height(for: options.count))
            .onChange(of: highlighted) { _, id in
                guard let id else { return }
                proxy.scrollTo(id)
            }
        }
    }

    private func height(for count: Int) -> CGFloat {
        let measured = contentHeight > 0 ? contentHeight : Self.estimatedHeight(rows: count)
        return min(max(measured, Metrics.rowHeight), Self.maxListHeight)
    }

    private static func estimatedHeight(rows: Int) -> CGFloat {
        CGFloat(rows) * (Metrics.rowHeight + Metrics.gutter) + Metrics.spacingWide
    }

    private func pick(_ id: String) {
        onClose()
        onSelect(id)
    }

    private func handle(key: ComposerKey) -> Bool {
        switch key {
        case .up, .down:
            let ids = options.map(\.id)
            highlighted = MenuRows.stepped(from: highlighted, by: key == .up ? -1 : 1, in: ids)
            return true
        case .returnKey, .commandReturn:
            guard let highlighted else { return false }
            pick(highlighted)
            return true
        case .escape:
            onClose()
            return true
        case .tab:
            return false
        }
    }
}
