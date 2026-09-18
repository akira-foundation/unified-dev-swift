import SwiftUI
import Core

struct NoticeStage: ViewModifier {
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(NoticePlacement.settingKey) private var placement = NoticePlacement.standard

    func body(content: Content) -> some View {
        content
            .overlayPreferenceValue(ComposerDockBounds.self) { docks in
                GeometryReader { proxy in
                    let clearance = placement.clearsComposer
                        ? NoticePlacement.composerClearance(
                            composerTops: docks.map { proxy[$0].minY },
                            columnHeight: proxy.size.height
                        )
                        : 0
                    banner
                        .padding(.bottom, clearance)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                }
            }
            .animation(Motion.pane, value: app.notice)
            .animation(Motion.pane, value: placement)
    }

    @ViewBuilder
    private var banner: some View {
        if let notice = app.notice {
            NoticeBanner(notice: notice) { app.notice = nil }
                .transition(entrance)
        }
    }

    private var alignment: Alignment {
        switch placement {
        case .topCentre: .top
        case .topTrailing: .topTrailing
        case .aboveComposer: .bottom
        }
    }

    private var entrance: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let edge: Edge = switch placement.entrance {
        case .top: .top
        case .trailing: .trailing
        case .bottom: .bottom
        }
        return .move(edge: edge).combined(with: .opacity)
    }
}

extension View {
    func noticeStage() -> some View {
        modifier(NoticeStage())
    }
}
