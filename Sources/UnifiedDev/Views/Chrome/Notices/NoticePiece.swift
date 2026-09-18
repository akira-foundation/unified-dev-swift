import SwiftUI
import Core

struct NoticePiece<Content: View, Actions: View>: View {
    var tone: NoticeTone
    var announcement: String?
    var onDismiss: (() -> Void)?
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    init(
        tone: NoticeTone, announcement: String? = nil, onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content, @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) {
        self.tone = tone
        self.announcement = announcement
        self.onDismiss = onDismiss
        self.content = content()
        self.actions = actions()
    }

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.gutter) {
            Image(systemName: tone.symbol)
                .font(Typo.label)
                .foregroundStyle(tone.colour)
                .padding(.top, Metrics.spacingHair)
                .accessibilityHidden(true)

            content
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: Metrics.spacing) {
                actions
                if let onDismiss {
                    Button("Dismiss", systemImage: "xmark", action: onDismiss)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .help("Dismiss")
                }
            }
            .fixedSize()
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, Metrics.spacingWide + Metrics.spacingSmall)
        .onChange(of: announcement, initial: true) { _, said in
            if let said { AccessibilityNotification.Announcement(said).post() }
        }
    }
}

struct NoticeGlass: ViewModifier {
    var tone: NoticeTone

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private static let tintStrength = 0.08

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
        content
            .clipShape(shape)
            .background {
                if reduceTransparency {
                    shape.fill(Palette.surfaceRaised)
                        .overlay(shape.fill(tone.colour.opacity(Self.tintStrength)))
                }
            }
            .glassEffect(
                reduceTransparency ? .identity : .regular.tint(tone.colour.opacity(Self.tintStrength)),
                in: shape
            )
    }
}

extension View {
    func noticeGlass(_ tone: NoticeTone) -> some View {
        modifier(NoticeGlass(tone: tone))
    }
}

extension NoticeTone {
    var colour: Color {
        switch ink {
        case .accent(let meanings): Palette.accent(beside: meanings)
        case .meaning(let meaning): meaning.colour
        }
    }
}

extension PaletteMeaning {
    var colour: Color {
        switch self {
        case .warning: Palette.warning
        case .negative: Palette.negative
        case .positive: Palette.positive
        case .running: Palette.running
        case .merged: Palette.merged
        }
    }
}
