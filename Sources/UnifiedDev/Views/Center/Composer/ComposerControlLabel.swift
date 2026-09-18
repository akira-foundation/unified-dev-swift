import SwiftUI

struct ComposerControlLabel<Icon: View>: View {
    var text: String?
    var tint: Color = Palette.textSecondary
    var isActive: Bool = false
    var showsMenuIndicator: Bool = false
    @ViewBuilder var icon: Icon

    var body: some View {
        content
            .font(Typo.label)
            .padding(.horizontal, Metrics.spacing)
            .padding(.vertical, Metrics.spacingSmall)
    }

    @ViewBuilder
    private var content: some View {
        let row = HStack(spacing: Metrics.spacingSmall) {
            icon

            if let text {
                Text(text).lineLimit(1)
            }

            if showsMenuIndicator {
                Image(systemName: "chevron.down")
                    .imageScale(.small)
            }
        }

        if isActive {
            row.foregroundStyle(Palette.accent)
        } else {
            row
        }
    }
}

extension ComposerControlLabel where Icon == Image {
    init(
        systemImage: String,
        text: String?,
        tint: Color = Palette.textSecondary,
        isActive: Bool = false,
        showsMenuIndicator: Bool = false
    ) {
        self.init(
            text: text,
            tint: tint,
            isActive: isActive,
            showsMenuIndicator: showsMenuIndicator
        ) {
            Image(systemName: systemImage)
        }
    }
}
