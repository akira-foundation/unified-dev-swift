import SwiftUI
import Core

struct WorkspaceNoticeStrip<Detail: View, Actions: View>: View {
    var tone: NoticeTone
    var title: String
    var onDismiss: (() -> Void)?
    @ViewBuilder var detail: Detail
    @ViewBuilder var actions: Actions

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        tone: NoticeTone, title: String, onDismiss: (() -> Void)? = nil,
        @ViewBuilder detail: () -> Detail, @ViewBuilder actions: () -> Actions
    ) {
        self.tone = tone
        self.title = title
        self.onDismiss = onDismiss
        self.detail = detail()
        self.actions = actions()
    }

    var body: some View {
        NoticePiece(tone: tone, announcement: tone.spoken(title), onDismiss: onDismiss) {
            VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                Text(title)
                    .font(Typo.labelEmphasis)
                    .foregroundStyle(Palette.textPrimary)
                    .layoutPriority(1)
                detail
            }
        } actions: {
            actions
                .controlSize(.small)
                .buttonStyle(.glass)
        }
        .noticeGlass(tone)
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, Metrics.spacingWide)
        .frame(maxWidth: .infinity)
        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}
