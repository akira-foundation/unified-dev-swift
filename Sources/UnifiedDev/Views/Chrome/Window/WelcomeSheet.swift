import AppKit
import SwiftUI
import Core

struct WelcomeSheet<Content: View, Secondary: View>: View {
    let title: String
    let subtitle: String
    let actionTitle: String
    let action: () -> Void
    let scrollTarget: AnyHashable?
    @ViewBuilder let secondary: () -> Secondary
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.welcomeVisibleHeight) private var visibleHeight

    private static var markSize: CGFloat { 72 }

    private var heightLimit: CGFloat {
        WelcomeSheetFit.heightLimit(forVisibleHeight: visibleHeight)
    }

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: Self.markSize, height: Self.markSize)
                .accessibilityHidden(true)

            Text(title)
                .font(Typo.display)
                .tracking(Typo.displayTracking)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, Metrics.inset + Metrics.spacingWide)
                .id(title)
                .transition(reduceMotion ? .identity : .opacity)
                .animation(reduceMotion ? nil : Motion.arrival, value: title)

            Text(subtitle)
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Metrics.spacing)
                .padding(.horizontal, Metrics.pane)
                .id(subtitle)
                .transition(reduceMotion ? .identity : .opacity)
                .animation(reduceMotion ? nil : Motion.arrival, value: subtitle)

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    content()
                        .frame(maxWidth: .infinity)
                        .padding(.top, Metrics.pane + Metrics.spacingSmall)
                }
                .scrollBounceBehavior(.basedOnSize)
                .onChange(of: scrollTarget) { _, target in
                    guard let target else { return }
                    withAnimation(reduceMotion ? nil : Motion.pane) {
                        proxy.scrollTo(target, anchor: .center)
                    }
                }
            }

            secondary()
                .padding(.top, Metrics.inset)

            Button(actionTitle, action: action)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(Palette.controlAccent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.top, Metrics.pane)
        }
        .padding(.horizontal, Metrics.pane + Metrics.spacingWide)
        .padding(.top, Metrics.pane + Metrics.inset)
        .padding(.bottom, Metrics.pane)
        .frame(maxWidth: .infinity, maxHeight: heightLimit)
        .background {
            Palette.surface
                .ignoresSafeArea(edges: .top)
        }
    }
}

extension WelcomeSheet where Secondary == EmptyView {
    init(
        title: String,
        subtitle: String,
        actionTitle: String,
        action: @escaping () -> Void,
        scrollTarget: AnyHashable? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            actionTitle: actionTitle,
            action: action,
            scrollTarget: scrollTarget,
            secondary: { EmptyView() },
            content: content
        )
    }
}
